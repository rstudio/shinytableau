import { DataTable } from "@tableau/extensions-api-types";
import { dataTableToInfo } from "./schema";
import { DataSpec, getData } from "./dataspec";

export class RPCHandler {
  async getData(spec: DataSpec, options?: any) {
    const dt = await getData(spec, options);
    return {
      ...dataTableToInfo(dt),
      data: dataTableData(dt),
      isTotalRowCountLimited: dt.isTotalRowCountLimited,
      isSummaryData: dt.isSummaryData,
    };
  }

  async saveSettings(settings: { [key: string]: string }, {save, add}: { save: boolean, add: boolean }) {
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
      if (value === null || typeof(value) === "undefined") {
        tableau.extensions.settings.erase(key);
      } else {
        tableau.extensions.settings.set(key, JSON.stringify(value));
      }
    }
    if (save) {
      await tableau.extensions.settings.saveAsync();
    }
  }
}

function dataTableData(dt: DataTable): { [column: string]: any[] } {
  const data = dt.data;

  const results: { [column: string]: any[] } = {};
  dt.columns.forEach((col, idx) => {
    results[col.fieldName] = dt.data.map(row => row[col.index].nativeValue);
  })
  return results;
}
