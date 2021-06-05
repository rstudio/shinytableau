import { DataTable, SelectionCriteria, RangeValue } from "@tableau/extensions-api-types";
import { dataTableToInfo } from "./schema";
import { DataSpec, getData } from "./dataspec";

export class RPCHandler {
  async getData(spec: DataSpec, options?: any) {
    const dt = await getData(spec, options);
    if (!dt) {
      // Can return null if spec is invalid, or if options.ignoreSelection:"never"
      return dt;
    }
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

  async selectMarksByValue(worksheet: string, criteria: SelectionCriteria[],
    updateType: "select-replace" | "select-add" | "select-remove"): Promise<void> {

    const ws = tableau.extensions.dashboardContent.dashboard.worksheets.find(ws => ws.name === worksheet);
    if (!ws) {
      throw new Error(`Unknown worksheet ${worksheet}`);
    }

    replaceInf(criteria);

    ws.selectMarksByValueAsync(criteria, updateType as any);
  }

  async selectMarksByValue2(worksheet: string, criteria: SelectionCriteria[],
    inverse_criteria: SelectionCriteria[][]): Promise<void> {
  
      const ws = tableau.extensions.dashboardContent.dashboard.worksheets.find(ws => ws.name === worksheet);
      if (!ws) {
        throw new Error(`Unknown worksheet ${worksheet}`);
      }

      const promises: Array<Promise<void>> = [];

      replaceInf(criteria);
      promises.push(ws.selectMarksByValueAsync(criteria, "select-replace" as any));
      for (const inv_cri of inverse_criteria) {
        replaceInf(inv_cri);
        for (const inv_cri_one of inv_cri) {
          promises.push(ws.selectMarksByValueAsync([inv_cri_one], "select-remove" as any));
        }
      }
      await Promise.all(promises);
  }
}

// JSON doesn't support Infinity/-Infinity directly. So for ranged values, we
// encode them as strings on the R side, and decode them here.
function replaceInf(criteria: SelectionCriteria[]) {
  for (const crit of criteria) {
    const rv = crit.value as any;
    if (rv.min === "Inf") {
      rv.min = 1000000000; // Infinity;
    } else if (rv.min === "-Inf") {
      rv.min = -1000000000; // -Infinity;
    }
    if (rv.max === "Inf") {
      rv.max = 1000000000; // Infinity;
    } else if (rv.min === "-Inf") {
      rv.max = -1000000000; // -Infinity;
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
