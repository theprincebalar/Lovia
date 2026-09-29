import React, { useState, useEffect } from "react";

export default function LegalManager({ authFetch, showToast }) {
  const [legal, setLegal] = useState({
    privacyPolicyUrl: "https://lovia-api.genxappstudio.cloud/privacy",
    termsConditionsUrl: "https://lovia-api.genxappstudio.cloud/terms",
    privacyPolicyTitle: "Lovia Privacy Policy",
    privacyPolicyHtml: "",
    termsConditionsTitle: "Lovia Terms of Service & EULA",
    termsConditionsHtml: "",
    lastUpdated: "2026-09-29"
  });
  const [loading, setLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);
  const [activeTab, setActiveTab] = useState("privacy");

  const fetchLegal = async () => {
    setLoading(true);
    try {
      const res = await authFetch("/api/admin/legal/get", { method: "POST" });
      if (res.ok) {
        const data = await res.json();
        setLegal(data);
      }
    } catch (err) {
      showToast("? Failed to load legal documents");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchLegal();
  }, []);

  const handleSave = async (e) => {
    if (e) e.preventDefault();
    setIsSaving(true);
    try {
      const res = await authFetch("/api/admin/legal", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(legal)
      });
      if (res.ok) {
        showToast("? Legal documents updated successfully!");
      } else {
        showToast("? Failed to update legal policies");
      }
    } catch (err) {
      showToast("? Network error saving legal policies");
    } finally {
      setIsSaving(false);
    }
  };

  if (loading) {
    return (
      <div style={{ textAlign: "center", padding: "60px 0", color: "var(--text-muted)" }}>
        <p>Loading legal documents...</p>
      </div>
    );
  }

  return (
    <div style={{ padding: "0 32px 60px" }}>
      {/* Header Info */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "24px" }}>
        <div>
          <h2 style={{ fontSize: "20px", fontWeight: 800, letterSpacing: "-0.3px" }}>?? Legal & Policy Management</h2>
          <p style={{ fontSize: "13px", color: "var(--text-muted)", marginTop: "4px" }}>
            Configure Privacy Policy & Terms of Service (EULA). Displayed inside the mobile app via native In-App WebView.
          </p>
        </div>
        <button
          onClick={handleSave}
          disabled={isSaving}
          style={{
            padding: "10px 24px",
            background: "linear-gradient(135deg, #FF4B72 0%, #7952FF 100%)",
            color: "#FFF",
            fontWeight: 800,
            borderRadius: "10px",
            border: "none",
            fontSize: "13px",
            cursor: isSaving ? "not-allowed" : "pointer",
            boxShadow: "0 4px 14px rgba(255, 75, 114, 0.3)"
          }}
        >
          {isSaving ? "Saving..." : "?? Save & Publish Legal Policies"}
        </button>
      </div>

      {/* Tab Switcher */}
      <div style={{ display: "flex", gap: "10px", marginBottom: "20px" }}>
        <button
          onClick={() => setActiveTab("privacy")}
          style={{
            padding: "10px 20px",
            borderRadius: "10px",
            border: "1px solid",
            borderColor: activeTab === "privacy" ? "#7952FF" : "var(--border-subtle)",
            backgroundColor: activeTab === "privacy" ? "rgba(121, 82, 255, 0.2)" : "rgba(255,255,255,0.03)",
            color: activeTab === "privacy" ? "#FFF" : "var(--text-muted)",
            fontWeight: 700,
            fontSize: "13px",
            cursor: "pointer"
          }}
        >
          ?? Privacy Policy
        </button>
        <button
          onClick={() => setActiveTab("terms")}
          style={{
            padding: "10px 20px",
            borderRadius: "10px",
            border: "1px solid",
            borderColor: activeTab === "terms" ? "#7952FF" : "var(--border-subtle)",
            backgroundColor: activeTab === "terms" ? "rgba(121, 82, 255, 0.2)" : "rgba(255,255,255,0.03)",
            color: activeTab === "terms" ? "#FFF" : "var(--text-muted)",
            fontWeight: 700,
            fontSize: "13px",
            cursor: "pointer"
          }}
        >
          ?? Terms of Service (EULA)
        </button>
      </div>

      {/* Content Form */}
      <div style={{
        backgroundColor: "var(--bg-secondary)",
        border: "1px solid var(--border-subtle)",
        borderRadius: "18px",
        padding: "24px"
      }}>
        {activeTab === "privacy" ? (
          <div style={{ display: "flex", flexDirection: "column", gap: "18px" }}>
            <div>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "6px" }}>
                <label style={{ fontSize: "12px", fontWeight: 700 }}>In-App WebView Target URL</label>
                <a
                  href={legal.privacyPolicyUrl}
                  target="_blank"
                  rel="noreferrer"
                  style={{ fontSize: "12px", color: "#00C9FF", textDecoration: "none", fontWeight: 600 }}
                >
                  ?? Open Live Page &rarr;
                </a>
              </div>
              <input
                type="text"
                value={legal.privacyPolicyUrl || ""}
                onChange={(e) => setLegal({ ...legal, privacyPolicyUrl: e.target.value })}
                placeholder="https://lovia-api.genxappstudio.cloud/privacy"
                style={{ width: "100%", padding: "10px 14px", background: "rgba(255,255,255,0.05)", border: "1px solid var(--border-subtle)", borderRadius: "8px", color: "#FFF", fontSize: "13px" }}
              />
              <p style={{ fontSize: "11px", color: "var(--text-muted)", marginTop: "4px" }}>
                This is the URL loaded by the Flutter in-app WebView when the user taps "Privacy Policy".
              </p>
            </div>

            <div>
              <label style={{ display: "block", fontSize: "12px", fontWeight: 700, marginBottom: "6px" }}>Page Title</label>
              <input
                type="text"
                value={legal.privacyPolicyTitle || ""}
                onChange={(e) => setLegal({ ...legal, privacyPolicyTitle: e.target.value })}
                placeholder="Lovia Privacy Policy"
                style={{ width: "100%", padding: "10px 14px", background: "rgba(255,255,255,0.05)", border: "1px solid var(--border-subtle)", borderRadius: "8px", color: "#FFF", fontSize: "13px" }}
              />
            </div>

            <div>
              <label style={{ display: "block", fontSize: "12px", fontWeight: 700, marginBottom: "6px" }}>
                Hosted Web Content (HTML) - Served at <code>/privacy</code>
              </label>
              <textarea
                rows={14}
                value={legal.privacyPolicyHtml || ""}
                onChange={(e) => setLegal({ ...legal, privacyPolicyHtml: e.target.value })}
                style={{
                  width: "100%",
                  padding: "12px",
                  background: "rgba(0,0,0,0.3)",
                  border: "1px solid var(--border-subtle)",
                  borderRadius: "8px",
                  color: "#E2E8F0",
                  fontFamily: "monospace",
                  fontSize: "12px",
                  resize: "vertical",
                  lineHeight: "1.5"
                }}
              />
            </div>
          </div>
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: "18px" }}>
            <div>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "6px" }}>
                <label style={{ fontSize: "12px", fontWeight: 700 }}>In-App WebView Target URL</label>
                <a
                  href={legal.termsConditionsUrl}
                  target="_blank"
                  rel="noreferrer"
                  style={{ fontSize: "12px", color: "#00C9FF", textDecoration: "none", fontWeight: 600 }}
                >
                  ?? Open Live Page &rarr;
                </a>
              </div>
              <input
                type="text"
                value={legal.termsConditionsUrl || ""}
                onChange={(e) => setLegal({ ...legal, termsConditionsUrl: e.target.value })}
                placeholder="https://lovia-api.genxappstudio.cloud/terms"
                style={{ width: "100%", padding: "10px 14px", background: "rgba(255,255,255,0.05)", border: "1px solid var(--border-subtle)", borderRadius: "8px", color: "#FFF", fontSize: "13px" }}
              />
              <p style={{ fontSize: "11px", color: "var(--text-muted)", marginTop: "4px" }}>
                This is the URL loaded by the Flutter in-app WebView when the user taps "Terms of Service (EULA)".
              </p>
            </div>

            <div>
              <label style={{ display: "block", fontSize: "12px", fontWeight: 700, marginBottom: "6px" }}>Page Title</label>
              <input
                type="text"
                value={legal.termsConditionsTitle || ""}
                onChange={(e) => setLegal({ ...legal, termsConditionsTitle: e.target.value })}
                placeholder="Lovia Terms of Service & EULA"
                style={{ width: "100%", padding: "10px 14px", background: "rgba(255,255,255,0.05)", border: "1px solid var(--border-subtle)", borderRadius: "8px", color: "#FFF", fontSize: "13px" }}
              />
            </div>

            <div>
              <label style={{ display: "block", fontSize: "12px", fontWeight: 700, marginBottom: "6px" }}>
                Hosted Web Content (HTML) - Served at <code>/terms</code>
              </label>
              <textarea
                rows={14}
                value={legal.termsConditionsHtml || ""}
                onChange={(e) => setLegal({ ...legal, termsConditionsHtml: e.target.value })}
                style={{
                  width: "100%",
                  padding: "12px",
                  background: "rgba(0,0,0,0.3)",
                  border: "1px solid var(--border-subtle)",
                  borderRadius: "8px",
                  color: "#E2E8F0",
                  fontFamily: "monospace",
                  fontSize: "12px",
                  resize: "vertical",
                  lineHeight: "1.5"
                }}
              />
            </div>
          </div>
        )}

        <div style={{ display: "flex", justifyContent: "flex-end", marginTop: "20px" }}>
          <button
            onClick={handleSave}
            disabled={isSaving}
            style={{
              padding: "10px 24px",
              background: "linear-gradient(135deg, #FF4B72 0%, #7952FF 100%)",
              color: "#FFF",
              fontWeight: 800,
              borderRadius: "8px",
              border: "none",
              fontSize: "13px",
              cursor: isSaving ? "not-allowed" : "pointer"
            }}
          >
            {isSaving ? "Saving Changes..." : "?? Save Changes"}
          </button>
        </div>
      </div>
    </div>
  );
}
