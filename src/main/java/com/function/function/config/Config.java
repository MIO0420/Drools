package com.function.function.config;

public class Config {

    // IAI (高科 iAI) API 設定 — OpenAI 相容格式
    public static final String IAI_API_KEY = System.getenv("IAI_API_KEY") != null
            ? System.getenv("IAI_API_KEY")
            : "sk-axPjnmys9F5c7IF_Agn-lQ";

    public static final String IAI_API_URL = System.getenv("IAI_API_URL") != null
            ? System.getenv("IAI_API_URL")
            : "https://www.iai.nkust.edu.tw/aihub/v1/chat/completions";

    public static final String IAI_MODEL = System.getenv("IAI_MODEL") != null
            ? System.getenv("IAI_MODEL")
            : "mistral-675b";

}