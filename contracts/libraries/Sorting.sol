// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

library Sorting {
  struct Node {
    uint key;
    uint value;
  }

  function sort(uint[] memory data) public view returns (uint[] memory) {
    return _quickSort(data, int(0), int(data.length - 1));
  }

  function sortNodes(Node[] memory nodes) public view returns (Node[] memory) {
    return _quickSortNodes(nodes, int(0), int(nodes.length - 1));
  }

  function _quickSort(
    uint[] memory arr,
    int left,
    int right
  ) private view returns (uint[] memory) {
    int i = left;
    int j = right;
    if (i == j) return arr;
    uint pivot = arr[uint(left + (right - left) / 2)];
    while (i <= j) {
      while (arr[uint(i)] < pivot) i++;
      while (pivot < arr[uint(j)]) j--;
      if (i <= j) {
        (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
        i++;
        j--;
      }
    }
    if (left < j) _quickSort(arr, left, j);
    if (i < right) _quickSort(arr, i, right);

    return arr;
  }

  function _quickSortNodes(
    Node[] memory nodes,
    int left,
    int right
  ) private view returns (Node[] memory) {
    int i = left;
    int j = right;
    if (i == j) return nodes;
    Node memory pivot = nodes[uint(left + (right - left) / 2)];
    while (i <= j) {
      while (nodes[uint(i)].value < pivot.value) i++;
      while (pivot.value < nodes[uint(j)].value) j--;
      if (i <= j) {
        (nodes[uint(i)], nodes[uint(j)]) = __swapNodes(nodes[uint(i)], nodes[uint(j)]);
        i++;
        j--;
      }
    }
    if (left < j) _quickSortNodes(nodes, left, j);
    if (i < right) _quickSortNodes(nodes, i, right);

    return nodes;
  }

  function __swapNodes(Node memory x, Node memory y) private pure returns (Node memory, Node memory) {
    Node memory tmp;
    (x, y) = (y, tmp);
    return (x, y);
  }
}
