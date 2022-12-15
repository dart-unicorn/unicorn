class GenerateDsl {
  const GenerateDsl({
    required Iterable<StateNode> stateNodes,
  });
}

class StateNode {
  const StateNode(
    String stateId,
    String name, {
    bool? initial,
    bool? terminal,
  });
}

class AvailableOn {
  const AvailableOn(Iterable<String> stateIds);
}

class TransferTo {
  const TransferTo(String stateId);
}

class Builder {
  const Builder();
}
