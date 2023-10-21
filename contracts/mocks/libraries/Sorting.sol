// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

library Sorting {
  struct Node {
    uint key;
    uint value;
  }

  struct Node3 {
    uint key;
    uint value;
    uint otherKey;
  }

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                   VALUE SORTING                                   //
  ///////////////////////////////////////////////////////////////////////////////////////

  function sort(uint[] memory data) internal pure returns (uint[] memory) {
    return _quickSort(data, int(0), int(data.length - 1));
  }

  function _quickSort(uint[] memory arr, int left, int right) private pure returns (uint[] memory) {
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

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                   NODE SORTING                                    //
  ///////////////////////////////////////////////////////////////////////////////////////

  function sort(address[] memory _keys, uint256[] memory _values) internal pure returns (address[] memory) {
    require(_values.length == _keys.length, "Sorting: invalid array length");
    if (_keys.length == 0) {
      return _keys;
    }

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

  function sort(uint256[] memory keys, uint256[] memory values) internal pure returns (uint256[] memory) {
    require(values.length == keys.length, "Sorting: invalid array length");
    if (keys.length == 0) {
      return keys;
    }

    Node[] memory _nodes = new Node[](keys.length);
    for (uint256 _i; _i < _nodes.length; _i++) {
      _nodes[_i] = Node(keys[_i], values[_i]);
    }
    _quickSortNodes(_nodes, int(0), int(_nodes.length - 1));

    for (uint256 _i; _i < _nodes.length; _i++) {
      keys[_i] = _nodes[_i].key; // Casting?
    }

    return keys;
  }

  function sortNodes(Node[] memory nodes) internal pure returns (Node[] memory) {
    return _quickSortNodes(nodes, int(0), int(nodes.length - 1));
  }

  function _quickSortNodes(Node[] memory nodes, int left, int right) private pure returns (Node[] memory) {
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

  ///////////////////////////////////////////////////////////////////////////////////////
  //                                  NODE3 SORTING                                    //
  ///////////////////////////////////////////////////////////////////////////////////////

  function sortWithExternalKeys(
    address[] memory _keys,
    uint256[] memory _values,
    uint256[] memory _otherKeys
  ) internal pure returns (address[] memory keys_, uint256[] memory otherKeys_) {
    require((_values.length == _keys.length) && (_otherKeys.length == _keys.length), "Sorting: invalid array length");
    if (_keys.length == 0) {
      return (_keys, _otherKeys);
    }

    Node3[] memory _nodes = new Node3[](_keys.length);
    for (uint256 _i; _i < _nodes.length; _i++) {
      _nodes[_i] = Node3(uint256(uint160(_keys[_i])), _values[_i], _otherKeys[_i]);
    }
    _quickSortNode3s(_nodes, int(0), int(_nodes.length - 1));

    for (uint256 _i; _i < _nodes.length; _i++) {
      _keys[_i] = address(uint160(_nodes[_i].key)); // Casting?
    }

    return (_keys, _otherKeys);
  }

  function sortNode3s(Node3[] memory nodes) internal pure returns (Node3[] memory) {
    return _quickSortNode3s(nodes, int(0), int(nodes.length - 1));
  }

  function _quickSortNode3s(Node3[] memory nodes, int left, int right) private pure returns (Node3[] memory) {
    int i = left;
    int j = right;
    if (i == j) return nodes;
    Node3 memory pivot = nodes[uint(left + (right - left) / 2)];
    while (i <= j) {
      while (nodes[uint(i)].value > pivot.value) i++;
      while (pivot.value > nodes[uint(j)].value) j--;
      if (i <= j) {
        (nodes[uint(i)], nodes[uint(j)]) = __swapNode3s(nodes[uint(i)], nodes[uint(j)]);
        i++;
        j--;
      }
    }
    if (left < j) nodes = _quickSortNode3s(nodes, left, j);
    if (i < right) nodes = _quickSortNode3s(nodes, i, right);

    return nodes;
  }

  function _bubbleSortNode3s(Node3[] memory nodes) private pure returns (Node3[] memory) {
    uint length = nodes.length;
    for (uint i = 0; i < length - 1; i++) {
      for (uint j = i + 1; j < length; j++) {
        if (nodes[j].value > nodes[i].value) {
          (nodes[i], nodes[j]) = __swapNode3s(nodes[i], nodes[j]);
        }
      }
    }
    return nodes;
  }

  function __swapNode3s(Node3 memory x, Node3 memory y) private pure returns (Node3 memory, Node3 memory) {
    Node3 memory tmp = x;
    (x, y) = (y, tmp);
    return (x, y);
  }
}
