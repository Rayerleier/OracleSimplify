library AstNode {
    enum NodeType {
        NUMBER,
        VARIABLE,
        OPERATION
    }

    // In Solidity, recursive nesting of structs is not allowed, so we can only create an AST through arrays.
    struct Info {
        NodeType nodeType;
        string value;
        uint256 left; // the index of left node
        uint256 right; // the index of right node
    }

}