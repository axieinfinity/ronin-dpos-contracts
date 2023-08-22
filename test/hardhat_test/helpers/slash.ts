export class IndicatorController {
  private _indicators: number[];

  constructor(_size: number) {
    this._indicators = new Array(_size).fill(0);
  }

  increaseAt(idx: number, value?: number) {
    value = value ?? 1;
    this._indicators[idx] += value;
  }

  setAt(idx: number, value: number) {
    this._indicators[idx] = value;
  }

  resetAt(idx: number) {
    this._indicators[idx] = 0;
  }

  getAt(idx: number): number {
    return this._indicators[idx];
  }
}

export class ScoreController {
  private _scores: number[];

  constructor(_size: number) {
    this._scores = new Array(_size).fill(0);
  }

  increaseAt(idx: number, value?: number) {
    value = value ?? 1;
    this._scores[idx] += value;
  }

  increaseAtWithUpperbound(idx: number, upperbound: number, value?: number) {
    value = value ?? 1;
    this._scores[idx] += value;

    if (this._scores[idx] > upperbound) {
      this._scores[idx] = upperbound;
    }
  }

  subAtNonNegative(idx: number, value: number) {
    this._scores[idx] -= value;

    if (this._scores[idx] < 0) {
      this._scores[idx] = 0;
    }
  }

  setAt(idx: number, value: number) {
    this._scores[idx] = value;
  }

  resetAt(idx: number) {
    this._scores[idx] = 0;
  }

  getAt(idx: number): number {
    return this._scores[idx];
  }
}
