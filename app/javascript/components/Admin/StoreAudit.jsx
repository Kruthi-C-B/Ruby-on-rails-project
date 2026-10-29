
import React, { useEffect, useState } from "react";
import { fetchGet } from "../../lib/api";
import { Alert, EmptyState, PageHeader, Spinner } from "../ui";

export default function StoreAudit() {
  const [auditData, setAuditData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    fetchGet("/api/v1/admin/audit_trail")
      .then((data) => {
        setAuditData(data.audit_trail || []);
      })
      .catch((err) => {
        console.error("Failed to load store audit trail:", err);
        setError("Failed to load audit records. Please try again.");
      })
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return <Spinner label="Loading store audit records…" />;
  }

  if (error) {
    return <Alert>{error}</Alert>;
  }

  return (
    <div>
      <PageHeader
        title="Store Product Listing Audit"
        description="Review product listing changes made by store owners across LocalFind."
      />

      <div className="lf-table-scroll">
        <table
          style={{
            width: "100%",
            borderCollapse: "collapse",
            textAlign: "left",
            marginTop: "20px",
          }}
          border="1"
          cellPadding="10"
        >
          <thead style={{ backgroundColor: "#f3f3f3" }}>
            <tr>
              <th>Date / Time</th>
              <th>Changed By</th>
              <th>Store</th>
              <th>Product</th>
              <th>Action</th>
              <th>Price (Before → After)</th>
              <th>Stock (Before → After)</th>
            </tr>
          </thead>

          <tbody>
            {auditData.length > 0 ? (
              auditData.map((log) => (
                <tr key={log.id}>
                  <td>
                    {log.date
                      ? new Date(log.date).toLocaleString()
                      : "—"}
                  </td>
                  <td>{log.actor || "Unknown"}</td>
                  <td>{log.store_name || "—"}</td>
                  <td>{log.product_name || "—"}</td>
                  <td>{log.event || "—"}</td>
                  <td>
                    {log.price_before != null &&
                    log.price_after != null
                      ? `${log.price_before} → ${log.price_after}`
                      : "—"}
                  </td>
                  <td>
                    {log.stock_before != null &&
                    log.stock_after != null
                      ? `${log.stock_before} → ${log.stock_after}`
                      : "—"}
                  </td>
                </tr>
              ))
            ) : (
              <tr>
              <td colSpan="7">
                <EmptyState title="No product listing changes recorded yet." />
              </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
