import { SettingsChangedEvent, DataTable } from "@tableau/extensions-api-types";
import { rejectInit, resolveInit } from "./init";
import { collectSchema } from "./schema";
import { RPCHandler } from "./rpchandler";

async function initShinyTableau() {
  console.time("tableau.extensions.initializeAsync");
  try {
    await tableau.extensions.initializeAsync({configure});
    resolveInit();
  } catch(err) {
    rejectInit(err);
    throw err;
  }
  console.timeEnd("tableau.extensions.initializeAsync");

  console.time("shinytableau startup");

  console.time("shinytableau collectSchema");
  const schema = await collectSchema();
  console.timeEnd("shinytableau collectSchema")

  // console.log(dataSourceInfoByWorksheet);
  // const dt = await dataSourcesByWorksheet["Sheet 1"][0].getUnderlyingDataAsync({columnsToInclude: ["Category", "Profit Ratio"]});
  // Shiny.setInputValue("shinytableau-testdata:tableau_datatable", serializeDataTable(dt));
  Shiny.setInputValue("shinytableau-schema:tableau_schema", schema);
  trackSettings();

  for (const ws of tableau.extensions.dashboardContent.dashboard.worksheets) {
    ws.addEventListener(tableau.TableauEventType.MarkSelectionChanged, () => {
      Shiny.setInputValue("shinytableau-selection", true, {priority: "event"});
    });
  }

  console.timeEnd("shinytableau startup");
}

$(document).on("shiny:sessioninitialized", () => {
  initShinyTableau().catch(err => {
    console.error(err);
  });
});

function configure() {
  let width = 600;
  let height = 400;
  const config = document.querySelector("script[type='application/json']#tableau-ext-config");
  if (config) {
    try {
      const options = JSON.parse(config.textContent);
      if (typeof(options.config_width) === "number") {
        width = options.config_width;
      }
      if (typeof(options.config_height) === "number") {
        height = options.config_height;
      }
    } catch (parse_err) {
      console.error(parse_err);
    }
  }

  (async function() {
    try {
      const url = new URL("?mode=configure", document.baseURI).href;
      console.log(`Opening configure, ${width} x ${height}`);
      const payload = "";
      await tableau.extensions.ui.displayDialogAsync(url, payload, {
        width, height
      });
    } catch (err) {
      // TODO
      console.error(err);
    }
  })();

  // Make compiler happy
  return {};
}

function serializeDataTable(dt: DataTable) {
  const names = dt.columns.map(col => col.fieldName);
  const values = dt.columns.map((col, index) => dt.data.map(row => row[index].value));
  return setNames(values, names);
}

function setNames(array: any[], names: string[]) {
  if (array.length !== names.length) {
    throw new Error("setNames: array and names must be same length");
  }
  const result: {[key: string]: any} = {};
  for (let i = 0; i < names.length; i++) {
    result[names[i]] = array[i];
  }
  return result;
}

function trackSettings() {
  let settings: {[key: string]: string} = {};
  function updateSettings(newSettings: {[key: string]: string}) {
    // Parse all values
    for (const [key, value] of Object.entries(newSettings)) {
      try {
        newSettings[key] = JSON.parse(value);
      } catch {
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
  tableau.extensions.settings.addEventListener(tableau.TableauEventType.SettingsChanged, (evt: SettingsChangedEvent) => {
    updateSettings(evt.newSettings);
  });
}

interface RPCRequest {
  method: string;
  args: any[];
  id: string;
}

let responseUrl: string | undefined;
Shiny.addCustomMessageHandler("shinytableau-rpc-init", ({url}: {url: string}) => {
  responseUrl = url;
});

const rpcHandler: {[method: string]: any} = new RPCHandler();
Shiny.addCustomMessageHandler("shinytableau-rpc", async (req: RPCRequest) => {
  if (!responseUrl) {
    throw new Error("shinytableau-rpc has not been initialized");
  }
  console.log("request:", req);

  let payload: {result?: string, error?: string} = {};
  try {
    if (!rpcHandler[req.method]) {
      throw new Error(`Method '${req.method}' does not exist`)
    }
    payload.result = await rpcHandler[req.method](...req.args);
  } catch(err) {
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
  })
});

Shiny.addCustomMessageHandler("shinytableau-close-dialog", value => {
  tableau.extensions.ui.closeDialog(value.payload);
});
