// 路徑：Graduate/src/main/java/com/function/model/ClockResult.java
package com.function.model;

import java.util.ArrayList;
import java.util.List;

public class ClockResult {

    private boolean      violated         = false;
    private List<String> violatedRules    = new ArrayList<>();
    private List<String> violatedMessages = new ArrayList<>();
    private List<String> warnings         = new ArrayList<>();
    private List<String> notes            = new ArrayList<>();

    // ─── addViolation ──────────────────────────────────────────────────────────
    public void addViolation(String ruleName, String message) {
        this.violated = true;
        this.violatedRules.add(ruleName);
        this.violatedMessages.add(message);
    }

    // ─── addWarning ────────────────────────────────────────────────────────────
    public void addWarning(String message) {
        this.warnings.add(message);
    }

    // ─── addNote ───────────────────────────────────────────────────────────────
    public void addNote(String message) {
        this.notes.add(message);
    }

    // ─── Getters ───────────────────────────────────────────────────────────────
    public boolean isViolated() {
        return violated;
    }

    public List<String> getViolatedRules() {
        return violatedRules;
    }

    public List<String> getViolatedMessages() {
        return violatedMessages;
    }

    public List<String> getWarnings() {
        return warnings;
    }

    public List<String> getNotes() {
        return notes;
    }

    // ─── toString（方便 log 觀察）──────────────────────────────────────────────
    @Override
    public String toString() {
        return "ClockResult{" +
               "violated="         + violated         +
               ", violatedRules="  + violatedRules    +
               ", violatedMessages=" + violatedMessages +
               ", warnings="       + warnings         +
               ", notes="          + notes            +
               '}';
    }
}
