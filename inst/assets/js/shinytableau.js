async function initShinyTableau() {
  console.time("initializeAsync");
  await tableau.extensions.initializeAsync({configure});
  console.timeEnd("initializeAsync");
}
initShinyTableau();

function configure() {
  window.alert("Not implemented yet");
}

