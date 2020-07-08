declare namespace Shiny {
  function setInputValue(name: string, value: any, opts?: {priority?: "event"}): void;
  
  function addCustomMessageHandler(type: string, handler: (message: {[key: string]: any}) => void): void;
  
  class InputBinding {
    constructor();
    find(scope: HTMLElement): HTMLElement[] | JQuery;
    initialize(el: HTMLElement): void;
    getId(el: HTMLElement): string | undefined;
    getType(): false | string;
    getValue(el: HTMLElement): any;
    subscribe(el: HTMLElement, callback: (allowDeferred: boolean) => void): void;
    unsubscribe(el: HTMLElement): void;
    receiveMessage(el: HTMLElement, data: {[key: string]: any}): void;
    getState(el: HTMLElement): any;
    getRatePolicy(el: HTMLElement): null | {policy: "throttle" | "debounce", delay: number};
    dispose(el: HTMLElement): void;
  }

  const inputBindings: {
    register(binding: InputBinding, bindingName: string, priority?: number): void;
  };
}
