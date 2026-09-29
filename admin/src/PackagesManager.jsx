import React, { useState, useEffect } from "react";

export default function PackagesManager({ authFetch, showToast }) {
  const [data, setData] = useState({ diamondPackages: [], subscriptionPlans: [] });
  const [loading, setLoading] = useState(true);
  const [isSaving, setIsSaving] = useState(false);

  const [editingDiamond, setEditingDiamond] = useState(null);
  const [editingPlan, setEditingPlan] = useState(null);

  const fetchPackages = async () => {
    setLoading(true);
    try {
      const res = await authFetch("/api/admin/packages/get", { method: "POST" });
      if (res.ok) {
        const pkgData = await res.json();
        setData({
          diamondPackages: pkgData.diamondPackages || [],
          subscriptionPlans: pkgData.subscriptionPlans || []
        });
      }
    } catch (err) {
      showToast("? Failed to load packages from server");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPackages();
  }, []);

  const saveAll = async (updatedData) => {
    setIsSaving(true);
    try {
      const res = await authFetch("/api/admin/packages", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(updatedData)
      });
      if (res.ok) {
        const resData = await res.json();
        setData(resData.packages);
        showToast("? Packages saved and synced successfully!");
      } else {
        showToast("? Server rejected packages update");
      }
    } catch (err) {
      showToast("? Failed to save packages");
    } finally {
      setIsSaving(false);
    }
  };

  const handleToggleDiamond = (id) => {
    const updated = {
      ...data,
      diamondPackages: data.diamondPackages.map(p =>
        p.id === id ? { ...p, isActive: !(p.isActive !== false) } : p
      )
    };
    setData(updated);
    saveAll(updated);
  };

  const handleDeleteDiamond = (id, title) => {
    if (!window.confirm(`Delete diamond package "${title}"?`)) return;
    const updated = {
      ...data,
      diamondPackages: data.diamondPackages.filter(p => p.id !== id)
    };
    setData(updated);
    saveAll(updated);
  };

  const handleSaveDiamond = (pkg) => {
    let updatedList;
    const exists = data.diamondPackages.some(p => p.id === pkg.id);
    if (exists) {
      updatedList = data.diamondPackages.map(p => p.id === pkg.id ? pkg : p);
    } else {
      updatedList = [...data.diamondPackages, pkg];
    }
    const updated = { ...data, diamondPackages: updatedList };
    setData(updated);
    saveAll(updated);
    setEditingDiamond(null);
  };

  const handleTogglePlan = (id) => {
    const updated = {
      ...data,
      subscriptionPlans: data.subscriptionPlans.map(p =>
        p.id === id ? { ...p, isActive: !(p.isActive !== false) } : p
      )
    };
    setData(updated);
    saveAll(updated);
  };

  const handleDeletePlan = (id, title) => {
    if (!window.confirm(`Delete VIP plan "${title}"?`)) return;
    const updated = {
      ...data,
      subscriptionPlans: data.subscriptionPlans.filter(p => p.id !== id)
    };
    setData(updated);
    saveAll(updated);
  };

  const handleSavePlan = (plan) => {
    let updatedList;
    const exists = data.subscriptionPlans.some(p => p.id === plan.id);
    if (exists) {
      updatedList = data.subscriptionPlans.map(p => p.id === plan.id ? plan : p);
    } else {
      updatedList = [...data.subscriptionPlans, plan];
    }
    const updated = { ...data, subscriptionPlans: updatedList };
    setData(updated);
    saveAll(updated);
    setEditingPlan(null);
  };

  if (loading) {
    return (
      <div style={{ textAlign: "center", padding: "60px 0", color: "var(--text-muted)" }}>
        <p>Loading package catalogue...</p>
      </div>
    );
  }
  return (
    <div style={{ padding: "0 32px 60px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "24px" }}>
        <div>
          <h2 style={{ fontSize: "20px", fontWeight: 800, letterSpacing: "-0.3px" }}>?? Store Packages & VIP Plans</h2>
          <p style={{ fontSize: "13px", color: "var(--text-muted)", marginTop: "4px" }}>
            Configure in-app diamond top-ups and VIP subscriptions. Changes reflect immediately on client devices.
          </p>
        </div>
        <button
          onClick={() => saveAll(data)}
          disabled={isSaving}
          style={{
            padding: "10px 22px",
            background: "linear-gradient(135deg, #00C9FF 0%, #92FE9D 100%)",
            color: "#071520",
            fontWeight: 800,
            borderRadius: "10px",
            border: "none",
            fontSize: "13px",
            cursor: isSaving ? "not-allowed" : "pointer",
            boxShadow: "0 4px 14px rgba(0, 201, 255, 0.3)"
          }}
        >
          {isSaving ? "Syncing..." : "?? Force Sync Packages"}
        </button>
      </div>

      <div style={{
        backgroundColor: "var(--bg-secondary)",
        border: "1px solid var(--border-subtle)",
        borderRadius: "18px",
        padding: "24px",
        marginBottom: "32px"
      }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "18px" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
            <span style={{ fontSize: "22px" }}>??</span>
            <div>
              <h3 style={{ fontSize: "16px", fontWeight: 700 }}>Diamond Coin Packages</h3>
              <p style={{ fontSize: "12px", color: "var(--text-muted)" }}>Non-consumable virtual diamond packs for messages & calls</p>
            </div>
          </div>
          <button
            onClick={() => setEditingDiamond({
              id: `pkg_${Date.now()}`,
              title: "New Diamond Pouch",
              coins: 100,
              bonusCoins: 0,
              priceUsd: 2.99,
              badge: "",
              productId: `lovia_diamonds_${Date.now()}`,
              isActive: true,
              isPopular: false,
              isBestValue: false
            })}
            style={{
              padding: "8px 16px",
              backgroundColor: "rgba(255, 255, 255, 0.08)",
              color: "#FFF",
              borderRadius: "8px",
              border: "1px solid var(--border-subtle)",
              fontSize: "12px",
              fontWeight: 600,
              cursor: "pointer"
            }}
          >
            ? Add Diamond Package
          </button>
        </div>

        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))", gap: "16px" }}>
          {data.diamondPackages.map((pkg) => {
            const isActive = pkg.isActive !== false;
            return (
              <div
                key={pkg.id}
                style={{
                  backgroundColor: "rgba(255, 255, 255, 0.03)",
                  border: `1px solid ${isActive ? "rgba(121, 82, 255, 0.3)" : "rgba(255, 255, 255, 0.08)"}`,
                  borderRadius: "14px",
                  padding: "16px",
                  display: "flex",
                  flexDirection: "column",
                  gap: "10px",
                  position: "relative"
                }}
              >
                {pkg.badge && (
                  <span style={{
                    position: "absolute",
                    top: 12,
                    right: 12,
                    fontSize: "10px",
                    fontWeight: 800,
                    padding: "2px 8px",
                    borderRadius: "6px",
                    backgroundColor: pkg.badge.includes("BEST") ? "#FFD700" : "#FF4B72",
                    color: "#000"
                  }}>
                    {pkg.badge}
                  </span>
                )}

                <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                  <span style={{ fontSize: "20px" }}>??</span>
                  <div>
                    <h4 style={{ fontSize: "15px", fontWeight: 700, color: "#FFF" }}>{pkg.title}</h4>
                    <p style={{ fontSize: "11px", color: "var(--text-muted)" }}>ID: {pkg.id}</p>
                  </div>
                </div>

                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginTop: "4px" }}>
                  <div>
                    <span style={{ fontSize: "22px", fontWeight: 800, color: "#00C9FF" }}>{pkg.coins}</span>
                    <span style={{ fontSize: "12px", color: "var(--text-muted)", marginLeft: "4px" }}>Diamonds</span>
                    {pkg.bonusCoins > 0 && (
                      <span style={{ fontSize: "11px", color: "#10B981", marginLeft: "6px", fontWeight: 700 }}>
                        (+{pkg.bonusCoins} Bonus)
                      </span>
                    )}
                  </div>
                  <div style={{ fontSize: "18px", fontWeight: 800, color: "#FFF" }}>
                    ${Number(pkg.priceUsd).toFixed(2)}
                  </div>
                </div>

                <div style={{ fontSize: "11px", color: "var(--text-muted)", background: "rgba(0,0,0,0.2)", padding: "6px 8px", borderRadius: "6px" }}>
                  Store Product ID: <code>{pkg.productId || "Auto-paired"}</code>
                </div>

                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: "6px", paddingTop: "10px", borderTop: "1px solid var(--border-subtle)" }}>
                  <label style={{ display: "flex", alignItems: "center", gap: "6px", fontSize: "12px", cursor: "pointer" }}>
                    <input
                      type="checkbox"
                      checked={isActive}
                      onChange={() => handleToggleDiamond(pkg.id)}
                      style={{ accentColor: "#7952FF" }}
                    />
                    <span style={{ color: isActive ? "#10B981" : "#94A3B8", fontWeight: 600 }}>
                      {isActive ? "Active" : "Disabled"}
                    </span>
                  </label>

                  <div style={{ display: "flex", gap: "8px" }}>
                    <button
                      onClick={() => setEditingDiamond(pkg)}
                      style={{
                        padding: "4px 10px",
                        backgroundColor: "rgba(255, 255, 255, 0.08)",
                        color: "#FFF",
                        borderRadius: "6px",
                        border: "none",
                        fontSize: "11px",
                        cursor: "pointer"
                      }}
                    >
                      ?? Edit
                    </button>
                    <button
                      onClick={() => handleDeleteDiamond(pkg.id, pkg.title)}
                      style={{
                        padding: "4px 10px",
                        backgroundColor: "rgba(239, 68, 68, 0.15)",
                        color: "#F87171",
                        borderRadius: "6px",
                        border: "none",
                        fontSize: "11px",
                        cursor: "pointer"
                      }}
                    >
                      ???
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
      <div style={{
        backgroundColor: "var(--bg-secondary)",
        border: "1px solid var(--border-subtle)",
        borderRadius: "18px",
        padding: "24px"
      }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "18px" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
            <span style={{ fontSize: "22px" }}>??</span>
            <div>
              <h3 style={{ fontSize: "16px", fontWeight: 700 }}>VIP Subscription Plans</h3>
              <p style={{ fontSize: "12px", color: "var(--text-muted)" }}>Recurring subscription access with included voice calling minutes</p>
            </div>
          </div>
          <button
            onClick={() => setEditingPlan({
              id: `sub_${Date.now()}`,
              title: "Monthly VIP Plus",
              period: "monthly",
              priceUsd: 14.99,
              voiceMinutes: 60,
              description: "60 minutes voice talk included",
              badge: "POPULAR",
              productId: `lovia_vip_monthly`,
              isActive: true,
              isPopular: false,
              isBestValue: false
            })}
            style={{
              padding: "8px 16px",
              backgroundColor: "rgba(255, 255, 255, 0.08)",
              color: "#FFF",
              borderRadius: "8px",
              border: "1px solid var(--border-subtle)",
              fontSize: "12px",
              fontWeight: 600,
              cursor: "pointer"
            }}
          >
            ? Add VIP Plan
          </button>
        </div>

        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(320px, 1fr))", gap: "16px" }}>
          {data.subscriptionPlans.map((plan) => {
            const isActive = plan.isActive !== false;
            return (
              <div
                key={plan.id}
                style={{
                  backgroundColor: "rgba(255, 255, 255, 0.03)",
                  border: `1px solid ${isActive ? "rgba(255, 215, 0, 0.35)" : "rgba(255, 255, 255, 0.08)"}`,
                  borderRadius: "14px",
                  padding: "18px",
                  display: "flex",
                  flexDirection: "column",
                  gap: "12px",
                  position: "relative"
                }}
              >
                {plan.badge && (
                  <span style={{
                    position: "absolute",
                    top: 12,
                    right: 12,
                    fontSize: "10px",
                    fontWeight: 800,
                    padding: "3px 10px",
                    borderRadius: "6px",
                    backgroundColor: "#FFD700",
                    color: "#000"
                  }}>
                    {plan.badge}
                  </span>
                )}

                <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                  <span style={{ fontSize: "24px" }}>??</span>
                  <div>
                    <h4 style={{ fontSize: "16px", fontWeight: 800, color: "#FFF" }}>{plan.title}</h4>
                    <span style={{
                      fontSize: "10px",
                      textTransform: "uppercase",
                      letterSpacing: "0.5px",
                      padding: "2px 6px",
                      borderRadius: "4px",
                      backgroundColor: "rgba(121, 82, 255, 0.2)",
                      color: "#C084FC",
                      fontWeight: 700
                    }}>
                      {plan.period}
                    </span>
                  </div>
                </div>

                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
                  <div>
                    <span style={{ fontSize: "24px", fontWeight: 800, color: "#FFD700" }}>
                      ${Number(plan.priceUsd).toFixed(2)}
                    </span>
                    <span style={{ fontSize: "12px", color: "var(--text-muted)" }}>/{plan.period}</span>
                  </div>
                  <div style={{ fontSize: "12px", color: "#10B981", fontWeight: 700 }}>
                    ?? {plan.voiceMinutes} mins call
                  </div>
                </div>

                <p style={{ fontSize: "12px", color: "var(--text-muted)", margin: 0 }}>
                  {plan.description}
                </p>

                <div style={{ fontSize: "11px", color: "var(--text-muted)", background: "rgba(0,0,0,0.2)", padding: "6px 8px", borderRadius: "6px" }}>
                  RevenueCat ID: <code>{plan.productId || "Auto-paired"}</code>
                </div>

                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: "6px", paddingTop: "10px", borderTop: "1px solid var(--border-subtle)" }}>
                  <label style={{ display: "flex", alignItems: "center", gap: "6px", fontSize: "12px", cursor: "pointer" }}>
                    <input
                      type="checkbox"
                      checked={isActive}
                      onChange={() => handleTogglePlan(plan.id)}
                      style={{ accentColor: "#FFD700" }}
                    />
                    <span style={{ color: isActive ? "#10B981" : "#94A3B8", fontWeight: 600 }}>
                      {isActive ? "Active Plan" : "Disabled"}
                    </span>
                  </label>

                  <div style={{ display: "flex", gap: "8px" }}>
                    <button
                      onClick={() => setEditingPlan(plan)}
                      style={{
                        padding: "5px 12px",
                        backgroundColor: "rgba(255, 255, 255, 0.08)",
                        color: "#FFF",
                        borderRadius: "6px",
                        border: "none",
                        fontSize: "11px",
                        cursor: "pointer"
                      }}
                    >
                      ?? Edit
                    </button>
                    <button
                      onClick={() => handleDeletePlan(plan.id, plan.title)}
                      style={{
                        padding: "5px 12px",
                        backgroundColor: "rgba(239, 68, 68, 0.15)",
                        color: "#F87171",
                        borderRadius: "6px",
                        border: "none",
                        fontSize: "11px",
                        cursor: "pointer"
                      }}
                    >
                      ???
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Edit Diamond Modal */}
      {editingDiamond && (
        <div style={{
          position: "fixed", inset: 0, backgroundColor: "rgba(0,0,0,0.75)",
          backdropFilter: "blur(5px)", display: "flex", alignItems: "center",
          justifyContent: "center", zIndex: 1000, padding: "20px"
        }}>
          <div style={{
            backgroundColor: "var(--bg-secondary)", border: "1px solid var(--border-subtle)",
            borderRadius: "16px", width: "100%", maxWidth: "480px", padding: "24px"
          }}>
            <h3 style={{ fontSize: "17px", fontWeight: 800, marginBottom: "16px" }}>?? Edit Diamond Package</h3>
            <form onSubmit={(e) => { e.preventDefault(); handleSaveDiamond(editingDiamond); }}>
              <div style={{ display: "flex", flexDirection: "column", gap: "14px" }}>
                <div>
                  <label style={{ display: "block", fontSize: "11px", fontWeight: 700, marginBottom: "4px" }}>Title</label>
                  <input
                    type="text"
                    value={editingDiamond.title}
                    onChange={(e) => setEditingDiamond({ ...editingDiamond, title: e.target.value })}
                    required
                    style={{ width: "100%", padding: "8px 12px", background: "rgba(255,255,255,0.05)", border: "1px solid var(--border-subtle)", borderRadius: "8px", color: "#FFF", fontSize: "13px" }}
                  />
                </div>
                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "10px" }}>
                  <div>
                    <label style={{ display: "block", fontSize: "11px", fontWeight: 700, marginBottom: "4px" }}>Base Diamonds</label>
                    <input
                      type="number"
                      value={editingDiamond.coins}
                      onChange={(e) => setEditingDiamond({ ...editingDiamond, coins: parseInt(e.target.value, 10) || 0 })}
                      required
                      style={{ width: "100%", padding: "8px 12px", background: "rgba(255,255,255,0.05)", border: "1px solid var(--border-subtle)", borderRadius: "8px", color: "#FFF", fontSize: "13px" }}
                    />
                  </div>
                  <div>
                    <label style={{ display: "block", fontSize: "11px", fontWeight: 700, marginBottom: "4px" }}>Bonus Diamonds</label>
                    <input
                      type="number"
                      value={editingDiamond.bonusCoins || 0}
                      onChange={(e) => setEditingDiamond({ ...editingDiamond, bonusCoins: parseInt(e.target.value, 10) || 0 })}
                      style={{ width: "100%", padding: "8px 12px", background: "rgba(255,255,255,0.05)", border: "1px solid var(--border-subtle)", borderRadius: "8px", color: "#FFF", fontSize: "13px" }}
                    />
                  </div>
                </div>
                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "10px" }}>
                  <div>
                    <label style={{ display: "block", fontSize: "11px", fontWeight: 700, marginBottom: "4px" }}>Price (USD $)</label>
                    <input
                      type="number"
                      step="0.01"
                      value={editingDiamond.priceUsd}
                      onChange={(e) => setEditingDiamond({ ...editingDiamond, priceUsd: parseFloat(e.target.value) || 0 })}
                      required
                      style={{ width: "100%", padding: "8px 12px", background: "rgba(255,255,255,0.05)", border: "1px solid var(--border-subtle)", borderRadius: "8px", color: "#FFF", fontSize: "13px" }}
                    />
                  </div>
                  <div>
                    <label style={{ display: "block", fontSize: "11px", fontWeight: 700, marginBottom: "4px" }}>Badge (Optional)</label>
                    <input
                      type="text"
                      placeholder="e.g. POPULAR, BEST VALUE"
                      value={editingDiamond.badge || ""}
                      onChange={(e) => setEditingDiamond({ ...editingDiamond, badge: e.target.value })}
                      style={{ width: "100%", padding: "8px 12px", background: "rgba(255,255,255,0.05)", border: "1px solid var(--border-subtle)", borderRadius: "8px", color: "#FFF", fontSize: "13px" }}
                    />
                  </div>
                </div>
                <div>
                  <label style={{ display: "block", fontSize: "11px", fontWeight: 700, marginBottom: "4px" }}>Store Product ID</label>
                  <input
                    type="text"
                    value={editingDiamond.productId || ""}
                    onChange={(e) => setEditingDiamond({ ...editingDiamond, productId: e.target.value })}
                    placeholder="e.g. lovia_diamonds_50"
                    style={{ width: "100%", padding: "8px 12px", background: "rgba(255,255,255,0.05)", border: "1px solid var(--border-subtle)", borderRadius: "8px", color: "#FFF", fontSize: "13px" }}
                  />
                </div>
                <div style={{ display: "flex", gap: "20px", padding: "10px", background: "rgba(255,255,255,0.04)", borderRadius: "8px" }}>
                  <label style={{ display: "flex", alignItems: "center", gap: "6px", fontSize: "12px", cursor: "pointer" }}>
                    <input
                      type="checkbox"
                      checked={editingDiamond.isActive !== false}
                      onChange={(e) => setEditingDiamond({ ...editingDiamond, isActive: e.target.checked })}
                      style={{ accentColor: "#7952FF" }}
                    />
                    Active in Mobile Store
                  </label>
                  <label style={{ display: "flex", alignItems: "center", gap: "6px", fontSize: "12px", cursor: "pointer" }}>
                    <input
                      type="checkbox"
                      checked={editingDiamond.isPopular || false}
                      onChange={(e) => setEditingDiamond({ ...editingDiamond, isPopular: e.target.checked })}
                      style={{ accentColor: "#FF4B72" }}
                    />
                    Mark Most Popular
                  </label>
                </div>
              </div>
              <div style={{ display: "flex", justifyContent: "flex-end", gap: "10px", marginTop: "20px" }}>
                <button
                  type="button"
                  onClick={() => setEditingDiamond(null)}
                  style={{ padding: "8px 16px", background: "rgba(255,255,255,0.08)", color: "#FFF", border: "none", borderRadius: "8px", fontSize: "12px" }}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  style={{ padding: "8px 20px", background: "linear-gradient(135deg, #FF4B72 0%, #7952FF 100%)", color: "#FFF", border: "none", borderRadius: "8px", fontSize: "12px", fontWeight: 700 }}
                >
                  Save Package
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Edit VIP Plan Modal */}
      {editingPlan && (
        <div style={{
          position: "fixed", inset: 0, backgroundColor: "rgba(0,0,0,0.75)",
          backdropFilter: "blur(5px)", display: "flex", alignItems: "center",
          justifyContent: "center", zIndex: 1000, padding: "20px"
        }}>
          <div style={{
            backgroundColor: "var(--bg-secondary)", border: "1px solid var(--border-subtle)",
            borderRadius: "16px", width: "100%", maxWidth: "480px", padding: "24px"
          }}>
            <h3 style={{ fontSize: "17px", fontWeight: 800, marginBottom: "16px" }}>?? Edit VIP Subscription Plan</h3>
            <form onSubmit={(e) => { e.preventDefault(); handleSavePlan(editingPlan); }}>
              <div style={{ display: "flex", flexDirection: "column", gap: "14px" }}>
                <div>
                  <label style={{ display: "block", fontSize: "11px", fontWeight: 700, marginBottom: "4px" }}>Plan Title</label>
                  <input
                    type="text"
                    value={editingPlan.title}
                    onChange={(e) => setEditingPlan({ ...editingPlan, title: e.target.value })}
                    required
                    style={{ width: "100%", padding: "8px 12px", background: "rgba(255,255,255,0.05)", border: "1px solid var(--border-subtle)", borderRadius: "8px", color: "#FFF", fontSize: "13px" }}
                  />
                </div>
                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "10px" }}>
                  <div>
                    <label style={{ display: "block", fontSize: "11px", fontWeight: 700, marginBottom: "4px" }}>Billing Cycle</label>
                    <select
                      value={editingPlan.period}
                      onChange={(e) => setEditingPlan({ ...editingPlan, period: e.target.value })}
                      style={{ width: "100%", padding: "8px 12px", background: "#1C182A", border: "1px solid var(--border-subtle)", borderRadius: "8px", color: "#FFF", fontSize: "13px" }}
                    >
                      <option value="weekly">Weekly</option>
                      <option value="monthly">Monthly</option>
                      <option value="yearly">Yearly</option>
                    </select>
                  </div>
                  <div>
                    <label style={{ display: "block", fontSize: "11px", fontWeight: 700, marginBottom: "4px" }}>Price (USD $)</label>
                    <input
                      type="number"
                      step="0.01"
                      value={editingPlan.priceUsd}
                      onChange={(e) => setEditingPlan({ ...editingPlan, priceUsd: parseFloat(e.target.value) || 0 })}
                      required
                      style={{ width: "100%", padding: "8px 12px", background: "rgba(255,255,255,0.05)", border: "1px solid var(--border-subtle)", borderRadius: "8px", color: "#FFF", fontSize: "13px" }}
                    />
                  </div>
                </div>
                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "10px" }}>
                  <div>
                    <label style={{ display: "block", fontSize: "11px", fontWeight: 700, marginBottom: "4px" }}>Included Call Minutes</label>
                    <input
                      type="number"
                      value={editingPlan.voiceMinutes}
                      onChange={(e) => setEditingPlan({ ...editingPlan, voiceMinutes: parseInt(e.target.value, 10) || 0 })}
                      required
                      style={{ width: "100%", padding: "8px 12px", background: "rgba(255,255,255,0.05)", border: "1px solid var(--border-subtle)", borderRadius: "8px", color: "#FFF", fontSize: "13px" }}
                    />
                  </div>
                  <div>
                    <label style={{ display: "block", fontSize: "11px", fontWeight: 700, marginBottom: "4px" }}>Badge (Optional)</label>
                    <input
                      type="text"
                      placeholder="e.g. MOST POPULAR"
                      value={editingPlan.badge || ""}
                      onChange={(e) => setEditingPlan({ ...editingPlan, badge: e.target.value })}
                      style={{ width: "100%", padding: "8px 12px", background: "rgba(255,255,255,0.05)", border: "1px solid var(--border-subtle)", borderRadius: "8px", color: "#FFF", fontSize: "13px" }}
                    />
                  </div>
                </div>
                <div>
                  <label style={{ display: "block", fontSize: "11px", fontWeight: 700, marginBottom: "4px" }}>Perks Description</label>
                  <input
                    type="text"
                    value={editingPlan.description || ""}
                    onChange={(e) => setEditingPlan({ ...editingPlan, description: e.target.value })}
                    placeholder="e.g. 50 minutes voice talk included"
                    style={{ width: "100%", padding: "8px 12px", background: "rgba(255,255,255,0.05)", border: "1px solid var(--border-subtle)", borderRadius: "8px", color: "#FFF", fontSize: "13px" }}
                  />
                </div>
                <div>
                  <label style={{ display: "block", fontSize: "11px", fontWeight: 700, marginBottom: "4px" }}>RevenueCat Store Identifier</label>
                  <input
                    type="text"
                    value={editingPlan.productId || ""}
                    onChange={(e) => setEditingPlan({ ...editingPlan, productId: e.target.value })}
                    placeholder="e.g. lovia_vip_monthly"
                    style={{ width: "100%", padding: "8px 12px", background: "rgba(255,255,255,0.05)", border: "1px solid var(--border-subtle)", borderRadius: "8px", color: "#FFF", fontSize: "13px" }}
                  />
                </div>
                <div style={{ display: "flex", gap: "20px", padding: "10px", background: "rgba(255,255,255,0.04)", borderRadius: "8px" }}>
                  <label style={{ display: "flex", alignItems: "center", gap: "6px", fontSize: "12px", cursor: "pointer" }}>
                    <input
                      type="checkbox"
                      checked={editingPlan.isActive !== false}
                      onChange={(e) => setEditingPlan({ ...editingPlan, isActive: e.target.checked })}
                      style={{ accentColor: "#FFD700" }}
                    />
                    Active Plan
                  </label>
                  <label style={{ display: "flex", alignItems: "center", gap: "6px", fontSize: "12px", cursor: "pointer" }}>
                    <input
                      type="checkbox"
                      checked={editingPlan.isPopular || false}
                      onChange={(e) => setEditingPlan({ ...editingPlan, isPopular: e.target.checked })}
                      style={{ accentColor: "#FF4B72" }}
                    />
                    Most Popular
                  </label>
                  <label style={{ display: "flex", alignItems: "center", gap: "6px", fontSize: "12px", cursor: "pointer" }}>
                    <input
                      type="checkbox"
                      checked={editingPlan.isBestValue || false}
                      onChange={(e) => setEditingPlan({ ...editingPlan, isBestValue: e.target.checked })}
                      style={{ accentColor: "#10B981" }}
                    />
                    Best Value
                  </label>
                </div>
              </div>
              <div style={{ display: "flex", justifyContent: "flex-end", gap: "10px", marginTop: "20px" }}>
                <button
                  type="button"
                  onClick={() => setEditingPlan(null)}
                  style={{ padding: "8px 16px", background: "rgba(255,255,255,0.08)", color: "#FFF", border: "none", borderRadius: "8px", fontSize: "12px" }}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  style={{ padding: "8px 20px", background: "linear-gradient(135deg, #FFD700 0%, #FF8A00 100%)", color: "#000", border: "none", borderRadius: "8px", fontSize: "12px", fontWeight: 800 }}
                >
                  Save Plan
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
