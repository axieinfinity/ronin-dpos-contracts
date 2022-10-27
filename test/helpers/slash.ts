export class IndicatorController {
  private localIndicators: number[];

  constructor(indicatorSize: number) {
    this.localIndicators = new Array(indicatorSize).fill(0);
  }

  increaseLocalCounterForValidatorAt(idx: number, value?: number) {
    value = value ?? 1;
    this.localIndicators[idx] += value;
  }

  setLocalCounterForValidatorAt(idx: number, value: number) {
    this.localIndicators[idx] = value;
  }

  resetLocalCounterForValidatorAt(idx: number) {
    this.localIndicators[idx] = 0;
  }

  getLocalCounterForValidatorAt(idx: number): number {
    return this.localIndicators[idx];
  }
}
