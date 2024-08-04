import Chart from "chart.js/auto"
import _ from "lodash"

export default {
  mounted() {
    this.chart = setupChart(this.el)
  },
  updated() {
    this.chart.destroy()
    this.chart = setupChart(this.el)
  }
}

const data = {
  labels: ['Red', 'Orange', 'Yellow', 'Green', 'Blue'],
  datasets: [
    {
      label: 'Dataset 1',
      data: [1, 2, 3, 4, 5],
    }
  ]
};


const setupChart = (el) => {
  const colors = JSON.parse(el.dataset['colors'])
  const values = JSON.parse(el.dataset['values'])

  const entries = Object.entries(values)
  const labels = entries.map(e => e[0])

  return new Chart(
    el,
    {
      type: 'pie',
      data: 
        {
          labels,
          datasets: [
            {
              label: "R$",
              data: entries.map(e => Number(e[1])),
              backgroundColor: labels.map(l => colors[l])
            }
          ]
        },
      options: {
        plugins: {
          legend: {
            display: false
          }
        }
      }
    }
  )
}
