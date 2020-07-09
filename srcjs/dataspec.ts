import { GetSummaryDataOptions, DataTable, GetUnderlyingDataOptions } from "@tableau/extensions-api-types";

export interface DataSpec {
  readonly worksheet: string;
  readonly source: "summary" | "underlying" | "datasource";
}
export async function getData(spec: DataSpec, options: any): Promise<DataTable | null> {
  if (isSummaryDataSpec(spec)) {
    return await getSummaryData(spec, options);
  } else if (isUnderlyingDataSpec(spec)) {
    return await getUnderlyingData(spec, options);
  } else if (isDataSourceDataSpec(spec)) {
    return await getDataSourceData(spec, options);
  } else {
    throw new Error("Unexpected data spec format");
  }
}

interface SummaryDataSpec extends DataSpec {
  readonly source: "summary";
}
function isSummaryDataSpec(spec: DataSpec): spec is SummaryDataSpec {
  return spec.source === "summary";
}
async function getSummaryData(spec: SummaryDataSpec, options?: GetSummaryDataOptions) {
  const ws = tableau.extensions.dashboardContent.dashboard.worksheets.find(ws => ws.name === spec.worksheet);
  if (!ws) {
    return null;
  }
  return await ws.getSummaryDataAsync(options);
}

interface UnderlyingDataSpec extends DataSpec {
  readonly source: "underlying";
  readonly table: string;
}
function isUnderlyingDataSpec(spec: DataSpec): spec is UnderlyingDataSpec {
  return spec.source === "underlying";
}
async function getUnderlyingData(spec: UnderlyingDataSpec, options?: GetUnderlyingDataOptions) {
  const ws = tableau.extensions.dashboardContent.dashboard.worksheets.find(ws => ws.name === spec.worksheet);
  if (!ws) {
    return null;
  }
  return await ws.getUnderlyingTableDataAsync(spec.table, options);
}

interface DataSourceDataSpec extends DataSpec {
  readonly source: "datasource";
  readonly ds: string;
  readonly table: string;
}
function isDataSourceDataSpec(spec: DataSpec): spec is DataSourceDataSpec {
  return spec.source === "datasource";
}
async function getDataSourceData(spec: DataSourceDataSpec, options?: GetUnderlyingDataOptions) {
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

