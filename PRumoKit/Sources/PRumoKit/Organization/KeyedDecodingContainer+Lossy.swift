extension KeyedDecodingContainer {
    func decodeLossy<Value: Decodable>(_ type: Value.Type, forKey key: Key, default fallback: Value) -> Value {
        (try? decodeIfPresent(type, forKey: key)) ?? fallback
    }

    func decodeLossySet<Value: RawRepresentable & Hashable>(_ type: Value.Type, forKey key: Key) -> Set<Value> where Value.RawValue == String {
        let raw = (try? decodeIfPresent([String].self, forKey: key)) ?? []
        return Set(raw.compactMap(Value.init(rawValue:)))
    }

    func decodeLossyArray<Element: Decodable>(_ type: Element.Type, forKey key: Key) -> [Element] {
        let nodes = (try? decodeIfPresent([LossyNode<Element>].self, forKey: key)) ?? []
        return nodes.compactMap(\.value)
    }

    func decodeLossyDictionary<Element: Decodable>(_ type: Element.Type, forKey key: Key) -> [String: Element] {
        let nodes = (try? decodeIfPresent([String: LossyNode<Element>].self, forKey: key)) ?? [:]
        return nodes.compactMapValues(\.value)
    }
}
