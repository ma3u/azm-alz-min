# Deployment Report Example

![Deployment Report Dashboard](https://via.placeholder.com/800x400/0078d4/ffffff?text=Azure+Landing+Zone+Deployment+Report)

**Example Report Output:**

```json
{
  "reportId": "20250929-113516",
  "timestamp": "2025-09-29T09:35:16Z",
  "environment": "sandbox",
  "template": "cost-optimized-alz",
  "status": "succeeded",
  "metrics": {
    "resourceCount": 18,
    "estimatedMonthlyCost": 30,
    "securityScore": 85,
    "deploymentDurationMinutes": 1
  },
  "recommendations": ["Sandbox deployment complete - costs should be $18-30/month for basic ALZ"]
}
```

**Dashboard Features:**

- 📊 Resource breakdown by type
- 💰 Cost estimation and trends
- 🛡️ Security compliance scoring
- 📈 Historical deployment analysis
- 🔧 Actionable recommendations

View actual reports in: `reports/deployments/index.html`
