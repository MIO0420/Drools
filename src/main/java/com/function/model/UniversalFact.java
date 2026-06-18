package com.function.model;

import java.util.HashMap;
import java.util.Map;

public class UniversalFact {
    private String companyId;
    private String employeeId;
    private Map<String, Object> data = new HashMap<>();

    public String getCompanyId() {
        return companyId;
    }

    public void setCompanyId(String companyId) {
        this.companyId = companyId;
    }

    public String getEmployeeId() {
        return employeeId;
    }

    public void setEmployeeId(String employeeId) {
        this.employeeId = employeeId;
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