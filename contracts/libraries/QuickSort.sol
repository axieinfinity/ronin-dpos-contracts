// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

library QuickSort {
  function sort(uint256[] memory data) public view returns (uint256[] memory) {
    return _quickSort(data, int256(0), int256(data.length - 1));
  }

  function _quickSort(
    uint256[] memory arr,
    int256 left,
    int256 right
  ) view private returns (uint256[] memory) {
    int256 i = left;
    int256 j = right;
    if (i == j) return arr;
    uint256 pivot = arr[uint256(left + (right - left) / 2)];
    while (i <= j) {
      while (arr[uint256(i)] < pivot) i++;
      while (pivot < arr[uint256(j)]) j--;
      if (i <= j) {
        (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
        i++;
        j--;
      }
    }
    if (left < j) _quickSort(arr, left, j);
    if (i < right) _quickSort(arr, i, right);

    return arr;
  }
}
