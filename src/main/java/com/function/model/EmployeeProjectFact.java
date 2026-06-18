package com.function.model;

public class EmployeeProjectFact {
    private String employeeId;
    private String projectId;

    // 建立建構子、Getters 與 Setters
    public EmployeeProjectFact() {}
    
    public EmployeeProjectFact(String employeeId, String projectId) {
        this.employeeId = employeeId;
        this.projectId = projectId;
    }

    public String getEmployeeId() { return employeeId; }
    public void setEmployeeId(String employeeId) { this.employeeId = employeeId; }
    
    public String getProjectId() { return projectId; }
    public void setProjectId(String projectId) { this.projectId = projectId; }
}