//
// SupabaseClient.swift
// Shared Supabase client instance and JSON coding helpers.
//

import Supabase
import Foundation

private enum DatabaseJSON {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://qiybcnabqyvcdzuwuslw.supabase.co")!,
    supabaseKey: "sb_publishable_XO8UIXBPZmoi3Usas9XkPA_eGo6-_6l",
    options: SupabaseClientOptions(
        db: .init(
            encoder: DatabaseJSON.encoder,
            decoder: DatabaseJSON.decoder
        )
    )
)
