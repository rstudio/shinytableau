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
    const dt = await dataSourcesByWorksheet["Sheet 1"][0].getUnderlyingDataAsync({columnsToInclude: ["Category", "Profit Ratio"]});
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
    (async function() {
      try {
        const url = new URL("?mode=configure", document.baseURI).href;
        console.log("Opening configure");
        const payload = "";
        const result = await tableau.extensions.ui.displayDialogAsync(url, payload, {
          // TODO: Make configurable
          width: 600,
          height: 400
        });
      } catch (err) {
        // TODO
        console.error(err);
      }
    })();
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
    const settings = {};
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
    }

    updateSettings(tableau.extensions.settings.getAll());
    tableau.extensions.settings.addEventListener(tableau.TableauEventType.SettingsChanged, evt => {
      updateSettings(evt.newSettings);
    });

    Shiny.addCustomMessageHandler("shinytableau-setting-update", ({settings, save}) => {
      for (const [key, value] of Object.entries(settings)) {
        tableau.extensions.settings.set(key, value);
      }
      if (save) {
        tableau.extensions.settings.saveAsync().then(
          result => {
            console.log("Tableau extension settings saved");
          },
          error => {
            console.error("Error saving extension settings");
            console.error(error);
          }
        );
      }
    });
  }
})();
