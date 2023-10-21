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
  const data = JSON.parse(el.dataset['categories'])

  const months = _.uniq(data.flatMap(c => {
    return Object.keys(c.values)
  }))

  const datasets = data.map(c => {
    return {
      label: c.category.name,
      data: months.map(month => Number(c.values[month] || 0)),
      tension: 0.3
    }
  })

  return new Chart(
    el,
    {
      type: 'line',
      data: {
        labels: months,
        datasets
      }
    }
  )
}
