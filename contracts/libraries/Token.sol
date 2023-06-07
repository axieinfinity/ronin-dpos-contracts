// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../interfaces/IWETH.sol";

library Token {
  /**
   * @dev Error indicating that the provided information is invalid.
   */
  error ErrInvalidInfo();

  /**
   * @dev Error indicating that the minting of ERC20 tokens has failed.
   */
  error ErrERC20MintingFailed();

  /**
   * @dev Error indicating that the minting of ERC721 tokens has failed.
   */
  error ErrERC721MintingFailed();

  /**
   * @dev Error indicating that an unsupported standard is encountered.
   */
  error ErrUnsupportedStandard();

  enum Standard {
    ERC20,
    ERC721
  }

  struct Info {
    Standard erc;
    // For ERC20:  the id must be 0 and the quantity is larger than 0.
    // For ERC721: the quantity must be 0.
    uint256 id;
    uint256 quantity;
  }

  // keccak256("TokenInfo(uint8 erc,uint256 id,uint256 quantity)");
  bytes32 public constant INFO_TYPE_HASH = 0x1e2b74b2a792d5c0f0b6e59b037fa9d43d84fbb759337f0112fcc15ca414fc8d;

  /**
   * @dev Returns token info struct hash.
   */
  function hash(Info memory _info) internal pure returns (bytes32 digest) {
    assembly {
      let freeMemPtr := mload(0x40)
      mstore(freeMemPtr, INFO_TYPE_HASH)
      mstore(add(freeMemPtr, 0x20), mload(_info)) // _info.erc
      mstore(add(freeMemPtr, 0x40), mload(add(_info, 0x20))) // _info.id
      mstore(add(freeMemPtr, 0x60), mload(add(_info, 0x40))) // _info.quantity
      digest := keccak256(freeMemPtr, 0x80)
    }
  }

  /**
   * @dev Validates the token info.
   */
  function validate(Info memory _info) internal pure {
    if (
      !(_info.erc == Standard.ERC20 && _info.quantity > 0 && _info.id == 0) ||
      (_info.erc == Standard.ERC721 && _info.quantity == 0)
    ) revert ErrInvalidInfo();
  }

  /**
   * @dev Transfer asset from.
   *
   * Requirements:
   * - The `_from` address must approve for the contract using this library.
   *
   */
  function transferFrom(Info memory _info, address _from, address _to, address _token) internal {
    bool _success;
    bytes memory _data;
    if (_info.erc == Standard.ERC20) {
      (_success, _data) = _token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, _from, _to, _info.quantity));
      _success = _success && (_data.length == 0 || abi.decode(_data, (bool)));
    } else if (_info.erc == Standard.ERC721) {
      // bytes4(keccak256("transferFrom(address,address,uint256)"))
      (_success, ) = _token.call(abi.encodeWithSelector(0x23b872dd, _from, _to, _info.id));
    } else revert ErrUnsupportedStandard();

    if (!_success) {
      revert(
        string(
          abi.encodePacked(
            "Token: could not transfer ",
            toString(_info),
            " from ",
            Strings.toHexString(uint160(_from), 20),
            " to ",
            Strings.toHexString(uint160(_to), 20),
            " token ",
            Strings.toHexString(uint160(_token), 20)
          )
        )
      );
    }
  }

  /**
   * @dev Transfers ERC721 token and returns the result.
   */
  function tryTransferERC721(address _token, address _to, uint256 _id) internal returns (bool _success) {
    (_success, ) = _token.call(abi.encodeWithSelector(IERC721.transferFrom.selector, address(this), _to, _id));
  }

  /**
   * @dev Transfers ERC20 token and returns the result.
   */
  function tryTransferERC20(address _token, address _to, uint256 _quantity) internal returns (bool _success) {
    bytes memory _data;
    (_success, _data) = _token.call(abi.encodeWithSelector(IERC20.transfer.selector, _to, _quantity));
    _success = _success && (_data.length == 0 || abi.decode(_data, (bool)));
  }

  /**
   * @dev Transfer assets from current address to `_to` address.
   */
  function transfer(Info memory _info, address _to, address _token) internal {
    bool _success;
    if (_info.erc == Standard.ERC20) {
      _success = tryTransferERC20(_token, _to, _info.quantity);
    } else if (_info.erc == Standard.ERC721) {
      _success = tryTransferERC721(_token, _to, _info.id);
    } else revert ErrUnsupportedStandard();

    if (!_success) {
      revert(
        string(
          abi.encodePacked(
            "Token: could not transfer ",
            toString(_info),
            " to ",
            Strings.toHexString(uint160(_to), 20),
            " token ",
            Strings.toHexString(uint160(_token), 20)
          )
        )
      );
    }
  }

  /**
   * @dev Tries minting and transfering assets.
   *
   * @notice Prioritizes transfer native token if the token is wrapped.
   *
   */
  function handleAssetTransfer(
    Info memory _info,
    address payable _to,
    address _token,
    IWETH _wrappedNativeToken
  ) internal {
    bool _success;
    if (_token == address(_wrappedNativeToken)) {
      // Try sending the native token before transferring the wrapped token
      if (!_to.send(_info.quantity)) {
        _wrappedNativeToken.deposit{ value: _info.quantity }();
        transfer(_info, _to, _token);
      }
    } else if (_info.erc == Token.Standard.ERC20) {
      uint256 _balance = IERC20(_token).balanceOf(address(this));

      if (_balance < _info.quantity) {
        // bytes4(keccak256("mint(address,uint256)"))
        (_success, ) = _token.call(abi.encodeWithSelector(0x40c10f19, address(this), _info.quantity - _balance));
        if (!_success) revert ErrERC20MintingFailed();
      }

      transfer(_info, _to, _token);
    } else if (_info.erc == Token.Standard.ERC721) {
      if (!tryTransferERC721(_token, _to, _info.id)) {
        // bytes4(keccak256("mint(address,uint256)"))
        (_success, ) = _token.call(abi.encodeWithSelector(0x40c10f19, _to, _info.id));
        if (!_success) revert ErrERC721MintingFailed();
      }
    } else revert ErrUnsupportedStandard();
  }

  /**
   * @dev Returns readable string.
   */
  function toString(Info memory _info) internal pure returns (string memory) {
    return
      string(
        abi.encodePacked(
          "TokenInfo(",
          Strings.toHexString(uint160(_info.erc), 1),
          ",",
          Strings.toHexString(_info.id),
          ",",
          Strings.toHexString(_info.quantity),
          ")"
        )
      );
  }

  struct Owner {
    address addr;
    address tokenAddr;
    uint256 chainId;
  }

  // keccak256("TokenOwner(address addr,address tokenAddr,uint256 chainId)");
  bytes32 public constant OWNER_TYPE_HASH = 0x353bdd8d69b9e3185b3972e08b03845c0c14a21a390215302776a7a34b0e8764;

  /**
   * @dev Returns ownership struct hash.
   */
  function hash(Owner memory _owner) internal pure returns (bytes32 digest) {
    assembly {
      let freeMemPtr := mload(0x40)
      mstore(freeMemPtr, OWNER_TYPE_HASH)
      mstore(add(freeMemPtr, 0x20), mload(_owner)) // _owner.addr
      mstore(add(freeMemPtr, 0x40), mload(add(_owner, 0x20))) // _owner.tokenAddr
      mstore(add(freeMemPtr, 0x60), mload(add(_owner, 0x40))) // _owner.chainId
      digest := keccak256(freeMemPtr, 0x80)
    }
  }
}
