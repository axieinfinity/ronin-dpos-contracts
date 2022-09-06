// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

library Sorting {
  struct Node {
    uint key;
    uint value;
  }

  function sort(uint[] memory data) internal pure returns (uint[] memory) {
    return _quickSort(data, int(0), int(data.length - 1));
  }

  function sortNodes(Node[] memory nodes) internal pure returns (Node[] memory) {
    // return _bubbleSortNodes(nodes);
    return _quickSortNodes(nodes, int(0), int(nodes.length - 1));
  }

  function sort(address[] memory _keys, uint256[] memory _values) internal pure returns (address[] memory) {
    require(_keys.length > 0 && _values.length == _keys.length, "Sorting: invalid array length");
    Node[] memory _nodes = new Node[](_keys.length);
    for (uint256 _i; _i < _nodes.length; _i++) {
      _nodes[_i] = Node(uint256(uint160(_keys[_i])), _values[_i]);
    }
    _quickSortNodes(_nodes, int(0), int(_nodes.length - 1));

    for (uint256 _i; _i < _nodes.length; _i++) {
      _keys[_i] = address(uint160(_nodes[_i].key)); // Casting?
    }

    return _keys;
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
