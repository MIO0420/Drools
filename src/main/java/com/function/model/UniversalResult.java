package com.function.model;

import java.util.HashMap;
import java.util.Map;

public class UniversalResult {
    private boolean success = true;
    private String message;
    private Map<String, Object> data = new HashMap<>();

    public boolean isSuccess() {
        return success;
    }

    public void setSuccess(boolean success) {
        this.success = success;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }

    public Map<String, Object> getData() {
        return data;
    }

    public void setData(Map<String, Object> data) {
        this.data = data;
    }

    public Object getValue(String key) {
        return data.get(key);
    }

    public void setValue(String key, Object value) {
        this.data.put(key, value);
    }
}