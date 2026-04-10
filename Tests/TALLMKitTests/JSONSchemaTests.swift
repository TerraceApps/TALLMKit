import Testing
import Foundation
@testable import TALLMKit

@Suite("JSONSchema")
struct JSONSchemaTests {

    @Test("string produces {type:string}")
    func stringSchema() {
        let json = JSONSchema.string.toJSON()
        #expect(json["type"] as? String == "string")
        #expect(json.count == 1)
    }

    @Test("integer produces {type:integer}")
    func integerSchema() {
        let json = JSONSchema.integer.toJSON()
        #expect(json["type"] as? String == "integer")
    }

    @Test("number produces {type:number}")
    func numberSchema() {
        let json = JSONSchema.number.toJSON()
        #expect(json["type"] as? String == "number")
    }

    @Test("boolean produces {type:boolean}")
    func booleanSchema() {
        let json = JSONSchema.boolean.toJSON()
        #expect(json["type"] as? String == "boolean")
    }

    @Test("enum produces {type:string, enum:[...]}")
    func enumSchema() {
        let json = JSONSchema.enum(["C", "F"]).toJSON()
        #expect(json["type"] as? String == "string")
        #expect(json["enum"] as? [String] == ["C", "F"])
    }

    @Test("array produces {type:array, items:{...}}")
    func arraySchema() {
        let json = JSONSchema.array(of: .integer).toJSON()
        #expect(json["type"] as? String == "array")
        let items = json["items"] as? [String: Any]
        #expect(items?["type"] as? String == "integer")
    }

    @Test("object with required produces correct shape")
    func objectWithRequired() {
        let json = JSONSchema.object(
            properties: ["city": .string],
            required: ["city"]
        ).toJSON()
        #expect(json["type"] as? String == "object")
        let props = json["properties"] as? [String: [String: Any]]
        #expect(props?["city"]?["type"] as? String == "string")
        #expect(json["required"] as? [String] == ["city"])
    }

    @Test("object omits required key when array is empty")
    func objectEmptyRequired() {
        let json = JSONSchema.object(
            properties: ["city": .string],
            required: []
        ).toJSON()
        #expect(json["required"] == nil)
    }

    @Test("optional wraps inner schema and adds nullable:true")
    func optionalSchema() {
        let json = JSONSchema.optional(.string).toJSON()
        #expect(json["type"] as? String == "string")
        #expect(json["nullable"] as? Bool == true)
    }

    @Test("optional preserves inner enum values")
    func optionalEnumSchema() {
        let json = JSONSchema.optional(.enum(["C", "F"])).toJSON()
        #expect(json["type"] as? String == "string")
        #expect(json["enum"] as? [String] == ["C", "F"])
        #expect(json["nullable"] as? Bool == true)
    }

    @Test("nested object encodes recursively")
    func nestedObject() {
        let json = JSONSchema.object(
            properties: [
                "address": .object(properties: ["city": .string], required: ["city"])
            ],
            required: ["address"]
        ).toJSON()
        let props = json["properties"] as? [String: [String: Any]]
        let addr = props?["address"]
        #expect(addr?["type"] as? String == "object")
        let innerProps = addr?["properties"] as? [String: [String: Any]]
        #expect(innerProps?["city"]?["type"] as? String == "string")
    }
}
