import { tableauInitialized } from "./init";
import * as React from "react";
import * as ReactDOM from "react-dom";

interface WorksheetInfo {
  name: string;
  underlyingTables: LogicalTableInfo[];
}

interface LogicalTableInfo {
  caption: string;
  id: string;
}

class ChooseDataInputBinding extends Shiny.InputBinding {
  find(scope: HTMLElement): JQuery {
    return $(scope).find(".shinytableau-choose-data");
  }
  async initialize(el: HTMLElement): Promise<void> {
    const inner = el.querySelector(".shinytableau-choose-data-inner");

    try {
      await tableauInitialized();
      const worksheetInfos: WorksheetInfo[] = [];
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
      const props: ChooseDataProps = {
        id: this.getId(el),
        worksheets: worksheetInfos,
        source: data.source,
        aggregation: data.aggregation,
        ignore_aliases: data["ignore-aliases"],
        ignore_selection: data["ignore-selection"],
        include_all_columns: data["include-all-columns"],
        max_rows: data["max-rows"]
      };

      ReactDOM.render(<ChooseData {...props}/>, inner);
    } catch(err) {
      console.error("Initialization failed for #", this.getId(el));
      throw err;
    }
  }
  getValue(el: HTMLElement): any {
    // TODO: implement
    return null;
  }
  setValue(el: HTMLElement, value: any): void {
    // TODO: implement
  }
  subscribe(el: HTMLElement, callback: (allowDeferred: boolean) => void): void {
  }
  unsubscribe(el: HTMLElement): void {
  }
}

interface ChooseDataProps {
  id: string;
  worksheets: WorksheetInfo[];
  source: "any" | "worksheet" | "datasource";
  aggregation: "ask" | "summary" | "underlying";
  ignore_aliases: boolean | "ask";
  ignore_selection: boolean | "ask";
  include_all_columns: boolean | "ask";
  max_rows: number | "ask";
}

function ChooseData(props: ChooseDataProps) {
  const [worksheet, setWorksheet] = React.useState<string>("");
  const tables = React.useMemo(
    () => props.worksheets.find(ws => ws.name === worksheet)?.underlyingTables,
    [props.worksheets, worksheet]
  );

  function handleWorksheetChange(evt: React.ChangeEvent<HTMLSelectElement>) {
    setWorksheet(evt.currentTarget.value);
  }

  return <React.Fragment>
    <select onChange={handleWorksheetChange}>
      <option value="">Choose a worksheet</option>
      { props.worksheets.map(ws => <option>{ws.name}</option>) }
    </select>
    { worksheet && <WorksheetOptions worksheet={worksheet} {...props}/> }
  </React.Fragment>;
}

interface WorksheetOptionsProps extends ChooseDataProps {
  worksheet: string;
}

function WorksheetOptions(props: WorksheetOptionsProps) {
  const [aggregation, setAggregation] = React.useState<string>();

  return <React.Fragment>
    { props.aggregation === "ask" && <p>
      <AggregationChoice id={props.id} value="summary" label="Use summary data" onChecked={setAggregation}/>
      <AggregationChoice id={props.id} value="underlying" label="Use underlying data" onChecked={setAggregation}/>
    </p> }
    { aggregation === "underlying" &&
      <select>
        {
          props.worksheets.find(ws => ws.name === props.worksheet).underlyingTables.map(
            tbl => <option value={tbl.id}>{tbl.caption}</option>
          )
        }
      </select>
    }
  </React.Fragment> 
}

function AggregationChoice(props: {id: string, value: string, label: string,
  onChecked: (value: string) => void}) {

  function handleChange(evt: React.ChangeEvent<HTMLInputElement>) {
    if (evt.currentTarget.checked) {
      props.onChecked(props.value);
    }
  }

  const id = `${props.id}-aggregation-radio-${props.value}`;
  return <div>
    <input type="radio" name={`${props.id}-aggregation-radio`} id={id}
      value={props.value} onChange={handleChange}/>
    <label htmlFor={id}>{props.label}</label>
  </div>
}

export default new ChooseDataInputBinding();