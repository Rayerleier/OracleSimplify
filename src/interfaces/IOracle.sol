import "../libraries/AstNode.sol";

interface IOracle {
    function callback(uint256 _logicId) external;
}
