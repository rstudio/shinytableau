import { GetSummaryDataOptions, DataTable } from "@tableau/extensions-api-types";
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
}

function dataTableData(dt: DataTable): {[column: string]: any[]} {
  const data = dt.data;

  const results: {[column: string]: any[]} = {};
  dt.columns.forEach((col, idx) => {
    results[col.fieldName] = dt.data.map(row => row[col.index].nativeValue);
  })
  return results;
}