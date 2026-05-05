import Testing
@testable import TaigiTypeless

@Test func textPolisherRemovesWhisperSpecialTokensAndRepeatedWhitespace() {
    let polished = TextPolisher().polish("  這是一段 <|ml|><|ml|> 測試   文字\n\n")

    #expect(polished == "這是一段 測試 文字")
}

@Test func textPolisherCollapsesConsecutiveRepeatedClauses() {
    let polished = TextPolisher().polish("本地模型可以正常執行 本地模型可以正常執行 今天測試完成")

    #expect(polished == "本地模型可以正常執行 今天測試完成")
}
