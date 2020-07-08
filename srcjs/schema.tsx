import { tableauInitialized } from "./init"
import { Worksheet, DataTable, DataSource } from "@tableau/extensions-api-types";

interface FieldInfo {
  readonly aggregation: string;
  // Tableau errors with "Field.columnType API not yet implemented"
  // readonly columnType: "continuous" | "discrete";
  readonly dataSourceId: string;
  readonly description?: string;
  readonly id: string;
  readonly isCalculatedField: boolean;
  readonly isCombinedField: boolean;
  readonly isGenerated: boolean;
  readonly isHidden: boolean;
  readonly name: string;
  readonly role: "dimension" | "measure" | "unknown";
}

interface ColumnInfo {
  readonly dataType: "bool" | "date" | "date-time" | "float" | "int" | "spatial" | "string";
  readonly fieldName: string;
  readonly index: number;
  readonly isReferenced: boolean;
}

interface MarkInfo {
  readonly color: string;
  readonly tupleId?: number;
  readonly type: "area" | "bar" | "circle" | "gantt-bar" | "line" | "map" | "pie" | "polygon" | "shape" | "square" | "text";
}

interface DataTableInfo {
  readonly name: string;
  readonly columns: readonly ColumnInfo[];
  readonly marksInfo?: readonly MarkInfo[];
}

interface WorksheetInfo {
  readonly name: string;
  readonly summary: DataTableInfo;
  readonly dataSourceIds: readonly string[];
  readonly underlyingTables: DataTableInfo[];
}

interface DataSourceInfo {
  readonly id: string;
  readonly name: string;
  readonly fields: readonly FieldInfo[];
  readonly isExtract: boolean;
  readonly extractUpdateTime?: string;
  readonly logicalTables: DataTableInfo[];
}

export interface Schema {
  readonly worksheets: {[name: string]: WorksheetInfo};
  readonly dataSources: {[id: string]: DataSourceInfo};
}

export async function collectSchema(): Promise<Schema> {
  await tableauInitialized();

  const dataSourcePromises: {[id: string]: Promise<DataSourceInfo>} = {};
  const promises: Promise<WorksheetInfo>[] =
    tableau.extensions.dashboardContent.dashboard.worksheets.map(
      ws => collectWorksheet(ws, dataSourcePromises)
    );
  
  const worksheets: {[name: string]: WorksheetInfo} = {};
  for (const ws of await Promise.all(promises)) {
    worksheets[ws.name] = ws;
  }

  const dataSources: {[id: string]: DataSourceInfo} = {};
  for (const id of Object.keys(dataSourcePromises)) {
    dataSources[id] = await dataSourcePromises[id];
  }

  return {
    worksheets,
    dataSources
  };
}

async function collectWorksheet(ws: Worksheet, dsMap: {[id: string]: Promise<DataSourceInfo>}): Promise<WorksheetInfo> {
  const pDataSources = ws.getDataSourcesAsync();
  const pSummaryData = ws.getSummaryDataAsync({ignoreSelection: true});
  const dataSources = await pDataSources;
  const summaryData = await pSummaryData;

  const dataSourceIds: string[] = [];
  for (const ds of dataSources) {
    dataSourceIds.push(ds.id);
    if (!dsMap[ds.id]) {
      dsMap[ds.id] = collectDataSource(ds);
    }
  }

  const worksheetInfo: WorksheetInfo = {
    name: ws.name,
    summary: dataTableToInfo(summaryData),
    dataSourceIds,
    underlyingTables: await Promise.all((await ws.getUnderlyingTablesAsync()).map(async tbl => {
      return dataTableToInfo(await ws.getUnderlyingTableDataAsync(tbl.id, {
        ignoreAliases: false,
        ignoreSelection: true,
        includeAllColumns: true,
        maxRows: 1
      }));
    }))
  };

  return worksheetInfo;
}

function dataTableToInfo(dt: DataTable): DataTableInfo {
  return {
    name: dt.name,
    columns: dt.columns.map(col => ({
      dataType: col.dataType,
      fieldName: col.fieldName,
      index: col.index,
      isReferenced: col.isReferenced
    })),
    marksInfo: dt.marksInfo?.map(mark => ({
      color: mark.color,
      tupleId: mark.tupleId.valueOf(),
      type: mark.type
    })),
  };
}

async function collectDataSource(ds: DataSource): Promise<DataSourceInfo> {
  return {
    id: ds.id,
    fields: ds.fields.map(f => ({
      aggregation: f.aggregation,
      dataSourceId: f.dataSource.id,
      id: f.id,
      isCalculatedField: f.isCalculatedField,
      isCombinedField: f.isCombinedField,
      isGenerated: f.isGenerated,
      isHidden: f.isHidden,
      name: f.name,
      role: f.role,
      description: f.description
    })),
    isExtract: ds.isExtract,
    name: ds.name,
    extractUpdateTime: ds.extractUpdateTime,
    logicalTables: await Promise.all((await ds.getLogicalTablesAsync()).map(async tbl => {
      return dataTableToInfo(await ds.getLogicalTableDataAsync(tbl.id, {
        ignoreAliases: false,
        maxRows: 1
      }));
    }))
  };
}