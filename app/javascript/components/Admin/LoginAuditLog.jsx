import React, { useState, useEffect } from "react";
import { fetchGet } from "../../lib/api";

export default function LoginAuditLog() {
  const [logs, setLogs] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchGet("/api/v1/admin/login_audits")
      .then(setLogs)
      .catch((err) => setError(err.message));
  }, []);

  if (error) return <p style={{ color: "red" }}>Error loading audit logs: {error}</p>;

  return (
    <div style={{ marginTop: "40px", padding: "20px", background: "#fff", borderRadius: "8px", boxShadow: "0 2px 4px rgba(0,0,0,0.1)" }}>
      <h2>Security: User Login Audit Log</h2>
      <p style={{ color: "#666" }}>Monitoring the last 100 authentication attempts across the platform.</p>
      
      <table style={{ width: "100%", textAlign: "left", borderCollapse: "collapse", marginTop: "20px" }}>
        <thead>
          <tr style={{ backgroundColor: "#f4f4f4", borderBottom: "2px solid #ddd" }}>
            <th style={{ padding: "10px" }}>Timestamp</th>
            <th style={{ padding: "10px" }}>Email Attempted</th>
            <th style={{ padding: "10px" }}>IP Address</th>
            <th style={{ padding: "10px" }}>Status</th>
            <th style={{ padding: "10px" }}>Details</th>
          </tr>
        </thead>
        <tbody>
          {logs.map((log) => (
            <tr key={log.id} style={{ borderBottom: "1px solid #eee" }}>
              <td style={{ padding: "10px" }}>{log.created_at}</td>
              <td style={{ padding: "10px", fontWeight: "bold" }}>{log.email}</td>
              <td style={{ padding: "10px" }}>{log.ip_address}</td>
              <td style={{ padding: "10px" }}>
                <span style={{ 
                  padding: "4px 8px", 
                  borderRadius: "12px", 
                  fontSize: "0.85em",
                  backgroundColor: log.status === "success" ? "#d4edda" : "#f8d7da",
                  color: log.status === "success" ? "#155724" : "#721c24"
                }}>
                  {log.status.toUpperCase()}
                </span>
              </td>
              <td style={{ padding: "10px", color: "#666" }}>
                {log.failure_reason ? log.failure_reason.replace("_", " ") : "Authenticated"}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}