(function(){function r(e,n,t){function o(i,f){if(!n[i]){if(!e[i]){var c="function"==typeof require&&require;if(!f&&c)return c(i,!0);if(u)return u(i,!0);var a=new Error("Cannot find module '"+i+"'");throw a.code="MODULE_NOT_FOUND",a}var p=n[i]={exports:{}};e[i][0].call(p.exports,function(r){var n=e[i][1][r];return o(n||r)},p,p.exports,r,e,n,t)}return n[i].exports}for(var u="function"==typeof require&&require,i=0;i<t.length;i++)o(t[i]);return o}return r})()({1:[function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const init_1 = require("./init");
const React = (window.React);
const ReactDOM = (window.ReactDOM);
class ChooseDataInputBinding extends Shiny.InputBinding {
    find(scope) {
        return $(scope).find(".shinytableau-choose-data");
    }
    async initialize(el) {
        const inner = el.querySelector(".shinytableau-choose-data-inner");
        try {
            await init_1.tableauInitialized();
            const worksheetInfos = [];
            for (const ws of tableau.extensions.dashboardContent.dashboard.worksheets) {
                const tables = await ws.getUnderlyingTablesAsync();
                worksheetInfos.push({
                    name: ws.name,
                    underlyingTables: tables.map(tbl => ({
                        caption: tbl.caption,
                        id: tbl.id
                    }))
                });
            }
            const data = $(el).data();
            const props = {
                id: this.getId(el),
                worksheets: worksheetInfos,
                source: data.source,
                aggregation: data.aggregation,
                ignore_aliases: data["ignore-aliases"],
                ignore_selection: data["ignore-selection"],
                include_all_columns: data["include-all-columns"],
                max_rows: data["max-rows"]
            };
            ReactDOM.render(React.createElement(ChooseData, Object.assign({}, props)), inner);
        }
        catch (err) {
            console.error("Initialization failed for #", this.getId(el));
            throw err;
        }
    }
    getValue(el) {
        // TODO: implement
        return null;
    }
    setValue(el, value) {
        // TODO: implement
    }
    subscribe(el, callback) {
    }
    unsubscribe(el) {
    }
}
function ChooseData(props) {
    const [worksheet, setWorksheet] = React.useState("");
    const tables = React.useMemo(() => { var _a; return (_a = props.worksheets.find(ws => ws.name === worksheet)) === null || _a === void 0 ? void 0 : _a.underlyingTables; }, [props.worksheets, worksheet]);
    function handleWorksheetChange(evt) {
        setWorksheet(evt.currentTarget.value);
    }
    return React.createElement(React.Fragment, null,
        React.createElement("select", { onChange: handleWorksheetChange },
            React.createElement("option", { value: "" }, "Choose a worksheet"),
            props.worksheets.map(ws => React.createElement("option", null, ws.name))),
        worksheet && React.createElement(WorksheetOptions, Object.assign({ worksheet: worksheet }, props)));
}
function WorksheetOptions(props) {
    const [aggregation, setAggregation] = React.useState();
    return React.createElement(React.Fragment, null,
        props.aggregation === "ask" && React.createElement("p", null,
            React.createElement(AggregationChoice, { id: props.id, value: "summary", label: "Use summary data", onChecked: setAggregation }),
            React.createElement(AggregationChoice, { id: props.id, value: "underlying", label: "Use underlying data", onChecked: setAggregation })),
        aggregation === "underlying" &&
            React.createElement("select", null, props.worksheets.find(ws => ws.name === props.worksheet).underlyingTables.map(tbl => React.createElement("option", { value: tbl.id }, tbl.caption))));
}
function AggregationChoice(props) {
    function handleChange(evt) {
        if (evt.currentTarget.checked) {
            props.onChecked(props.value);
        }
    }
    const id = `${props.id}-aggregation-radio-${props.value}`;
    return React.createElement("div", null,
        React.createElement("input", { type: "radio", name: `${props.id}-aggregation-radio`, id: id, value: props.value, onChange: handleChange }),
        React.createElement("label", { htmlFor: id }, props.label));
}
exports.default = new ChooseDataInputBinding();

},{"./init":3}],2:[function(require,module,exports){
"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const choosedata_1 = require("./choosedata");
const init_1 = require("./init");
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
    const dashboard = tableau.extensions.dashboardContent.dashboard;
    const worksheets = [];
    const dataSourcesByWorksheet = {};
    const dataSourceInfoByWorksheet = {};
    for (const worksheet of dashboard.worksheets) {
        worksheets.push(worksheet.name);
        const dataSources = await worksheet.getDataSourcesAsync();
        dataSourcesByWorksheet[worksheet.name] = dataSources;
        dataSourceInfoByWorksheet[worksheet.name] = dataSources.map(ds => ({
            id: ds.id,
            name: ds.name,
            fields: ds.fields.map(field => ({
                aggregation: field.aggregation,
                // Tableau errors with "Not yet implemented"
                // columnType: field.columnType,
                description: field.description,
                id: field.id,
                isCalculatedField: field.isCalculatedField,
                isCombinedField: field.isCombinedField,
                isGenerated: field.isGenerated,
                isHidden: field.isHidden,
                name: field.name,
                role: field.role
            }))
        }));
        /*
        const logicalTables = await worksheet.getUnderlyingTablesAsync();
        for (const table of logicalTables) {
          console.log(`${table.id} - ${table.caption}`);
          const tableData = await worksheet.getUnderlyingTableDataAsync(table.id, {maxRows: 3});
          console.log(tableData);
        }
        */
    }
    Shiny.setInputValue("shinytableau-worksheets", worksheets);
    Shiny.setInputValue("shinytableau-datasources", dataSourceInfoByWorksheet);
    console.log(dataSourceInfoByWorksheet);
    const dt = await dataSourcesByWorksheet["Sheet 1"][0].getUnderlyingDataAsync({ columnsToInclude: ["Category", "Profit Ratio"] });
    Shiny.setInputValue("shinytableau-testdata:tableau_datatable", serializeDataTable(dt));
    trackSettings();
    console.timeEnd("shinytableau startup");
}
$(document).on("shiny:sessioninitialized", () => {
    initShinyTableau().catch(err => {
        console.error(err);
    });
});
function configure() {
    (async function () {
        try {
            const url = new URL("?mode=configure", document.baseURI).href;
            console.log("Opening configure");
            const payload = "";
            const result = await tableau.extensions.ui.displayDialogAsync(url, payload, {
                // TODO: Make configurable
                width: 600,
                height: 400
            });
        }
        catch (err) {
            // TODO
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
    Shiny.addCustomMessageHandler("shinytableau-setting-update", ({ settings, save }) => {
        for (const [key, value] of Object.entries(settings)) {
            if (typeof (value) === "string") {
                tableau.extensions.settings.set(key, value);
            }
            else if (value === null || typeof (value) === "undefined") {
                tableau.extensions.settings.erase(key);
            }
            else {
                tableau.extensions.settings.set(key, value.toString());
            }
        }
        if (save) {
            tableau.extensions.settings.saveAsync().then(result => {
                console.log("Tableau extension settings saved");
            }, error => {
                console.error("Error saving extension settings");
                console.error(error);
            });
        }
    });
}
Shiny.inputBindings.register(choosedata_1.default, "shinytableau.chooseDataInputBinding");

},{"./choosedata":1,"./init":3}],3:[function(require,module,exports){
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

},{}]},{},[2]);
