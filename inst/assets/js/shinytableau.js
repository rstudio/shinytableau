(function(){function r(e,n,t){function o(i,f){if(!n[i]){if(!e[i]){var c="function"==typeof require&&require;if(!f&&c)return c(i,!0);if(u)return u(i,!0);var a=new Error("Cannot find module '"+i+"'");throw a.code="MODULE_NOT_FOUND",a}var p=n[i]={exports:{}};e[i][0].call(p.exports,function(r){var n=e[i][1][r];return o(n||r)},p,p.exports,r,e,n,t)}return n[i].exports}for(var u="function"==typeof require&&require,i=0;i<t.length;i++)o(t[i]);return o}return r})()({1:[function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getData = void 0;
async function getData(spec, options) {
    if (isSummaryDataSpec(spec)) {
        return await getSummaryData(spec, options);
    }
    else if (isUnderlyingDataSpec(spec)) {
        return await getUnderlyingData(spec, options);
    }
    else if (isDataSourceDataSpec(spec)) {
        return await getDataSourceData(spec, options);
    }
    else {
        throw new Error("Unexpected data spec format");
    }
}
exports.getData = getData;
function isSummaryDataSpec(spec) {
    return spec.source === "summary";
}
async function getSummaryData(spec, options) {
    const ws = tableau.extensions.dashboardContent.dashboard.worksheets.find(ws => ws.name === spec.worksheet);
    if (!ws) {
        return null;
    }
    return await ws.getSummaryDataAsync(options);
}
function isUnderlyingDataSpec(spec) {
    return spec.source === "underlying";
}
async function getUnderlyingData(spec, options) {
    const ws = tableau.extensions.dashboardContent.dashboard.worksheets.find(ws => ws.name === spec.worksheet);
    if (!ws) {
        return null;
    }
    return await ws.getUnderlyingTableDataAsync(spec.table, options);
}
function isDataSourceDataSpec(spec) {
    return spec.source === "datasource";
}
async function getDataSourceData(spec, options) {
    const ws = tableau.extensions.dashboardContent.dashboard.worksheets.find(ws => ws.name === spec.worksheet);
    if (!ws) {
        return null;
    }
    const ds = (await ws.getDataSourcesAsync()).find(ds => ds.id === spec.ds);
    if (!ds) {
        return null;
    }
    return await ds.getLogicalTableDataAsync(spec.table, options);
}

},{}],2:[function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const init_1 = require("./init");
const schema_1 = require("./schema");
const rpchandler_1 = require("./rpchandler");
async function initShinyTableau() {
    console.time("tableau.extensions.initializeAsync");
    try {
        await tableau.extensions.initializeAsync({ configure });
        init_1.resolveInit();
    }
    catch (err) {
        init_1.rejectInit(err);
        throw err;
    }
    console.timeEnd("tableau.extensions.initializeAsync");
    console.time("shinytableau startup");
    console.time("shinytableau collectSchema");
    const schema = await schema_1.collectSchema();
    console.timeEnd("shinytableau collectSchema");
    // console.log(dataSourceInfoByWorksheet);
    // const dt = await dataSourcesByWorksheet["Sheet 1"][0].getUnderlyingDataAsync({columnsToInclude: ["Category", "Profit Ratio"]});
    // Shiny.setInputValue("shinytableau-testdata:tableau_datatable", serializeDataTable(dt));
    Shiny.setInputValue("shinytableau-schema:tableau_schema", schema);
    trackSettings();
    for (const ws of tableau.extensions.dashboardContent.dashboard.worksheets) {
        ws.addEventListener(tableau.TableauEventType.MarkSelectionChanged, () => {
            Shiny.setInputValue("shinytableau-selection", true, { priority: "event" });
        });
    }
    console.timeEnd("shinytableau startup");
}
function configure() {
    let width = 600;
    let height = 400;
    const config = document.querySelector("script[type='application/json']#tableau-ext-config");
    if (config) {
        try {
            const options = JSON.parse(config.textContent);
            if (typeof (options.config_width) === "number") {
                width = options.config_width;
            }
            if (typeof (options.config_height) === "number") {
                height = options.config_height;
            }
        }
        catch (parse_err) {
            console.error(parse_err);
        }
    }
    (async function () {
        try {
            const url = new URL("?mode=configure", document.baseURI).href;
            console.log(`Opening configure, ${width} x ${height}`);
            const payload = "";
            await tableau.extensions.ui.displayDialogAsync(url, payload, {
                width, height
            });
        }
        catch (err) {
            console.error(err);
        }
    })();
    // Make compiler happy
    return {};
}
function serializeDataTable(dt) {
    const names = dt.columns.map(col => col.fieldName);
    const values = dt.columns.map((col, index) => dt.data.map(row => row[index].value));
    return setNames(values, names);
}
function setNames(array, names) {
    if (array.length !== names.length) {
        throw new Error("setNames: array and names must be same length");
    }
    const result = {};
    for (let i = 0; i < names.length; i++) {
        result[names[i]] = array[i];
    }
    return result;
}
function trackSettings() {
    let settings = {};
    function updateSettings(newSettings) {
        // Parse all values
        for (const [key, value] of Object.entries(newSettings)) {
            try {
                newSettings[key] = JSON.parse(value);
            }
            catch (_a) {
                delete newSettings[key];
            }
        }
        const unsetKeys = [];
        for (const oldKey of Object.keys(settings)) {
            if (!newSettings.hasOwnProperty(oldKey)) {
                Shiny.setInputValue("shinytableau-setting-" + oldKey, null);
            }
        }
        for (const [key, value] of Object.entries(newSettings)) {
            Shiny.setInputValue("shinytableau-setting-" + key, value);
        }
        Shiny.setInputValue("shinytableau-settings", newSettings);
        settings = newSettings;
    }
    updateSettings(tableau.extensions.settings.getAll());
    tableau.extensions.settings.addEventListener(tableau.TableauEventType.SettingsChanged, (evt) => {
        updateSettings(evt.newSettings);
    });
}
Shiny.addCustomMessageHandler("shinytableau-init", message => {
    initShinyTableau().catch(err => {
        console.error(err);
    });
});
let responseUrl;
Shiny.addCustomMessageHandler("shinytableau-rpc-init", ({ url }) => {
    responseUrl = url;
});
const rpcHandler = new rpchandler_1.RPCHandler();
Shiny.addCustomMessageHandler("shinytableau-rpc", async (req) => {
    if (!responseUrl) {
        throw new Error("shinytableau-rpc has not been initialized");
    }
    console.log("request:", req);
    let payload = {};
    try {
        if (!rpcHandler[req.method]) {
            throw new Error(`Method '${req.method}' does not exist`);
        }
        payload.result = await rpcHandler[req.method](...req.args);
    }
    catch (err) {
        payload.error = err.message;
    }
    console.log("response:", payload);
    await fetch(responseUrl + (/\?/.test(responseUrl) ? "&" : "?") + "id=" + encodeURIComponent(req.id), {
        body: JSON.stringify(payload),
        method: "POST",
        credentials: "same-origin",
        headers: {
            "Content-Type": "application/json; charset=utf-8"
        }
    });
});
Shiny.addCustomMessageHandler("shinytableau-close-dialog", value => {
    tableau.extensions.ui.closeDialog(value.payload);
});

},{"./init":3,"./rpchandler":4,"./schema":5}],3:[function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.tableauInitialized = exports.rejectInit = exports.resolveInit = void 0;
let promise = new Promise((resolve, reject) => {
    exports.resolveInit = resolve;
    exports.rejectInit = reject;
});
async function tableauInitialized() {
    return promise;
}
exports.tableauInitialized = tableauInitialized;

},{}],4:[function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.RPCHandler = void 0;
const schema_1 = require("./schema");
const dataspec_1 = require("./dataspec");
class RPCHandler {
    async getData(spec, options) {
        const dt = await dataspec_1.getData(spec, options);
        return Object.assign(Object.assign({}, schema_1.dataTableToInfo(dt)), { data: dataTableData(dt), isTotalRowCountLimited: dt.isTotalRowCountLimited, isSummaryData: dt.isSummaryData });
    }
    async saveSettings(settings, { save, add }) {
        if (!add) {
            // If we're not adding to the existing settings, then erase all the
            // settings that aren't in the newly received settings.
            for (const key of Object.keys(tableau.extensions.settings.getAll())) {
                if (!Object.prototype.hasOwnProperty.call(settings, key)) {
                    tableau.extensions.settings.erase(key);
                }
            }
        }
        for (const [key, value] of Object.entries(settings)) {
            if (value === null || typeof (value) === "undefined") {
                tableau.extensions.settings.erase(key);
            }
            else {
                tableau.extensions.settings.set(key, JSON.stringify(value));
            }
        }
        if (save) {
            await tableau.extensions.settings.saveAsync();
        }
    }
    async selectMarksByValue(worksheet, criteria, updateType) {
        const ws = tableau.extensions.dashboardContent.dashboard.worksheets.find(ws => ws.name === worksheet);
        if (!ws) {
            throw new Error(`Unknown worksheet ${worksheet}`);
        }
        replaceInf(criteria);
        ws.selectMarksByValueAsync(criteria, updateType);
    }
    async selectMarksByValue2(worksheet, criteria, inverse_criteria) {
        const ws = tableau.extensions.dashboardContent.dashboard.worksheets.find(ws => ws.name === worksheet);
        if (!ws) {
            throw new Error(`Unknown worksheet ${worksheet}`);
        }
        const promises = [];
        replaceInf(criteria);
        promises.push(ws.selectMarksByValueAsync(criteria, "select-replace"));
        for (const inv_cri of inverse_criteria) {
            replaceInf(inv_cri);
            for (const inv_cri_one of inv_cri) {
                promises.push(ws.selectMarksByValueAsync([inv_cri_one], "select-remove"));
            }
        }
        await Promise.all(promises);
    }
}
exports.RPCHandler = RPCHandler;
// JSON doesn't support Infinity/-Infinity directly. So for ranged values, we
// encode them as strings on the R side, and decode them here.
function replaceInf(criteria) {
    for (const crit of criteria) {
        const rv = crit.value;
        if (rv.min === "Inf") {
            rv.min = 1000000000; // Infinity;
        }
        else if (rv.min === "-Inf") {
            rv.min = -1000000000; // -Infinity;
        }
        if (rv.max === "Inf") {
            rv.max = 1000000000; // Infinity;
        }
        else if (rv.min === "-Inf") {
            rv.max = -1000000000; // -Infinity;
        }
    }
}
function dataTableData(dt) {
    const data = dt.data;
    const results = {};
    dt.columns.forEach((col, idx) => {
        results[col.fieldName] = dt.data.map(row => row[col.index].nativeValue);
    });
    return results;
}

},{"./dataspec":1,"./schema":5}],5:[function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.dataTableToInfo = exports.collectSchema = void 0;
const init_1 = require("./init");
async function collectSchema() {
    await init_1.tableauInitialized();
    const dataSourcePromises = {};
    const promises = tableau.extensions.dashboardContent.dashboard.worksheets.map(ws => collectWorksheet(ws, dataSourcePromises));
    const worksheets = {};
    for (const ws of await Promise.all(promises)) {
        worksheets[ws.name] = ws;
    }
    const dataSources = {};
    for (const id of Object.keys(dataSourcePromises)) {
        dataSources[id] = await dataSourcePromises[id];
    }
    return {
        worksheets,
        dataSources
    };
}
exports.collectSchema = collectSchema;
async function collectWorksheet(ws, dsMap) {
    const pDataSources = ws.getDataSourcesAsync();
    const pSummaryData = ws.getSummaryDataAsync({ ignoreSelection: true });
    const dataSources = await pDataSources;
    const summaryData = await pSummaryData;
    const dataSourceIds = [];
    for (const ds of dataSources) {
        dataSourceIds.push(ds.id);
        if (!dsMap[ds.id]) {
            dsMap[ds.id] = collectDataSource(ds);
        }
    }
    const worksheetInfo = {
        name: ws.name,
        summary: dataTableToInfo(summaryData),
        dataSourceIds,
        underlyingTables: await Promise.all((await ws.getUnderlyingTablesAsync()).map(async (tbl) => {
            return dataTableToInfo(await ws.getUnderlyingTableDataAsync(tbl.id, {
                ignoreAliases: false,
                ignoreSelection: true,
                includeAllColumns: true,
                maxRows: 1
            }), tbl.id, tbl.caption);
        }))
    };
    return worksheetInfo;
}
function dataTableToInfo(dt, id, caption) {
    var _a;
    return {
        id,
        caption,
        name: dt.name,
        columns: dt.columns.map(col => ({
            dataType: col.dataType,
            fieldName: col.fieldName,
            index: col.index,
            isReferenced: col.isReferenced
        })),
        marksInfo: (_a = dt.marksInfo) === null || _a === void 0 ? void 0 : _a.map(mark => ({
            color: mark.color,
            tupleId: mark.tupleId.valueOf(),
            type: mark.type
        })),
    };
}
exports.dataTableToInfo = dataTableToInfo;
async function collectDataSource(ds) {
    var _a;
    return {
        id: ds.id,
        fields: ds.fields.map(f => {
            var _a;
            return ({
                aggregation: f.aggregation,
                id: f.id,
                name: f.name,
                description: (_a = f.description) !== null && _a !== void 0 ? _a : "",
                role: f.role,
                isCalculatedField: f.isCalculatedField,
                isCombinedField: f.isCombinedField,
                isGenerated: f.isGenerated,
                isHidden: f.isHidden
            });
        }),
        isExtract: ds.isExtract,
        name: ds.name,
        extractUpdateTime: (_a = ds.extractUpdateTime) !== null && _a !== void 0 ? _a : null,
        logicalTables: await Promise.all((await ds.getLogicalTablesAsync()).map(async (tbl) => {
            return dataTableToInfo(await ds.getLogicalTableDataAsync(tbl.id, {
                ignoreAliases: false,
                maxRows: 1
            }), tbl.id, tbl.caption);
        }))
    };
}

},{"./init":3}]},{},[2]);
