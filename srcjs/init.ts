export let resolveInit: (value: void | Promise<void>) => void;
export let rejectInit: (reason: any) => void;

let promise: Promise<void> = new Promise((resolve, reject) => {
  resolveInit = resolve;
  rejectInit = reject;
});

export async function tableauInitialized() {
  return promise;
}
