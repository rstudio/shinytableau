(function() {
  async function initShinyTableau() {
    console.time("tableau.extensions.initializeAsync");
    await tableau.extensions.initializeAsync({configure});
    console.timeEnd("tableau.extensions.initializeAsync");

    console.time("shinytableau startup");

    Shiny.setInputValue(
      "shinytableau-settings",
      tableau.extensions.settings.getAll()
    );

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
    }
    Shiny.setInputValue("shinytableau-worksheets", worksheets);
    Shiny.setInputValue("shinytableau-datasources", dataSourceInfoByWorksheet);

    // console.log(dataSourceInfoByWorksheet);
    // const dt = await dataSourcesByWorksheet["Sheet 1"][0].getUnderlyingDataAsync({columnsToInclude: ["Category", "Profit Ratio"]});
    // Shiny.setInputValue("shinytableau-testdata:tableau_datatable", serializeDataTable(dt));

    console.timeEnd("shinytableau startup");
  }

  initShinyTableau();

  function configure() {
    window.alert("Not implemented yet");
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
})();
