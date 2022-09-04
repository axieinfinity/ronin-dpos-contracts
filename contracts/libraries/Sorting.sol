// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

library Sorting {
  struct Node {
    uint key;
    uint value;
  }

  function sort(uint[] memory data) public pure returns (uint[] memory) {
    return _quickSort(data, int(0), int(data.length - 1));
  }

  function sortNodes(Node[] memory nodes) public pure returns (Node[] memory) {
    // return _bubbleSortNodes(nodes);
    return _quickSortNodes(nodes, int(0), int(nodes.length - 1));
  }

  function _quickSort(
    uint[] memory arr,
    int left,
    int right
  ) private pure returns (uint[] memory) {
    int i = left;
    int j = right;
    if (i == j) return arr;
    uint pivot = arr[uint(left + (right - left) / 2)];
    while (i <= j) {
      while (arr[uint(i)] > pivot) i++;
      while (pivot > arr[uint(j)]) j--;
      if (i <= j) {
        (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
        i++;
        j--;
      }
    }
    if (left < j) arr = _quickSort(arr, left, j);
    if (i < right) arr = _quickSort(arr, i, right);

    return arr;
  }

  function _quickSortNodes(
    Node[] memory nodes,
    int left,
    int right
  ) private pure returns (Node[] memory) {
    int i = left;
    int j = right;
    if (i == j) return nodes;
    Node memory pivot = nodes[uint(left + (right - left) / 2)];
    while (i <= j) {
      while (nodes[uint(i)].value > pivot.value) i++;
      while (pivot.value > nodes[uint(j)].value) j--;
      if (i <= j) {
        (nodes[uint(i)], nodes[uint(j)]) = __swapNodes(nodes[uint(i)], nodes[uint(j)]);
        i++;
        j--;
      }
    }
    if (left < j) nodes = _quickSortNodes(nodes, left, j);
    if (i < right) nodes = _quickSortNodes(nodes, i, right);

    return nodes;
  }

  function _bubbleSortNodes(Node[] memory nodes) private pure returns (Node[] memory) {
    uint length = nodes.length;
    for (uint i = 0; i < length - 1; i++) {
      for (uint j = i + 1; j < length; j++) {
        if (nodes[j].value > nodes[i].value) {
          (nodes[i], nodes[j]) = __swapNodes(nodes[i], nodes[j]);
        }
      }
    }
    return nodes;
  }

  function __swapNodes(Node memory x, Node memory y) private pure returns (Node memory, Node memory) {
    Node memory tmp = x;
    (x, y) = (y, tmp);
    return (x, y);
  }
}
