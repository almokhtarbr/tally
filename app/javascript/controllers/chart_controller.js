import { Controller } from "@hotwired/stimulus"
import "chart.js"

const PALETTE = [
  "#5046e5", "#a78bfa", "#0ea5e9", "#14b8a6", "#22c55e",
  "#f59e0b", "#ef4444", "#ec4899", "#8b5cf6", "#06b6d4",
  "#84cc16", "#f97316", "#6366f1", "#10b981", "#e11d48"
]

export default class extends Controller {
  static targets = ["canvas"]
  static values = { labels: Array, data: Array, data2: Array, color: String, color2: String, datasets: String }

  connect() {
    const Chart = window.Chart
    if (!Chart) return

    let datasets

    if (this.hasDatasetsValue && this.datasetsValue) {
      const parsed = JSON.parse(this.datasetsValue)
      datasets = parsed.map((ds, i) => ({
        label: ds.label || `Series ${i + 1}`,
        data: ds.data,
        borderColor: ds.color || PALETTE[i % PALETTE.length],
        backgroundColor: (ds.color || PALETTE[i % PALETTE.length]) + "0a",
        fill: i === 0, tension: 0.4, borderWidth: 1.5,
        pointRadius: 0, pointHoverRadius: 3,
        pointHoverBackgroundColor: ds.color || PALETTE[i % PALETTE.length]
      }))
    } else {
      const color1 = this.hasColorValue && this.colorValue ? this.colorValue : "#5046e5"
      const color2 = this.hasColor2Value && this.color2Value ? this.color2Value : "#a78bfa"

      datasets = [{
        label: "Pageviews",
        data: this.dataValue,
        borderColor: color1,
        backgroundColor: color1 + "0a",
        fill: true, tension: 0.4, borderWidth: 1.5,
        pointRadius: 0, pointHoverRadius: 3,
        pointHoverBackgroundColor: color1
      }]

      if (this.hasData2Value && this.data2Value.some(v => v > 0)) {
        datasets.push({
          label: "Events",
          data: this.data2Value,
          borderColor: color2,
          backgroundColor: color2 + "0a",
          fill: true, tension: 0.4, borderWidth: 1.5,
          pointRadius: 0, pointHoverRadius: 3,
          pointHoverBackgroundColor: color2
        })
      }
    }

    new Chart(this.canvasTarget, {
      type: "line",
      data: { labels: this.labelsValue, datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { intersect: false, mode: "index" },
        plugins: {
          legend: { display: datasets.length > 1, position: "top", align: "end", labels: { boxWidth: 8, boxHeight: 8, usePointStyle: true, font: { size: 11 }, color: "#8b8ba3", padding: 16 } },
          tooltip: {
            backgroundColor: "#1a1a2e", titleColor: "#8b8ba3", bodyColor: "#fff",
            padding: { x: 12, y: 8 }, cornerRadius: 8,
            titleFont: { size: 11, weight: "400" }, bodyFont: { size: 13, weight: "600" },
            displayColors: true, boxWidth: 8, boxHeight: 8, boxPadding: 4, usePointStyle: true
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: { precision: 0, color: "#c4c4d4", font: { size: 11 } },
            grid: { color: "#f0f0f5", drawBorder: false },
            border: { display: false }
          },
          x: {
            ticks: { color: "#c4c4d4", font: { size: 11 }, maxRotation: 0, maxTicksLimit: 8 },
            grid: { display: false },
            border: { display: false }
          }
        }
      }
    })
  }
}
