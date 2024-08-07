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
  const dates = JSON.parse(el.dataset['dates'])
  const colors = JSON.parse(el.dataset['colors'])
  const values = JSON.parse(el.dataset['values'])

  const entries = Object.entries(values)
  const labels = entries.map(e => e[0])

  const data = {
    labels,
    datasets: [
      {
        label: "R$",
        data: entries.map(e => Number(e[1])),
        backgroundColor: labels.map(l => colors[l])
      }
    ]
  }


  return new Chart(
    el,
    {
      type: 'pie',
      data,
      options: {
        plugins: {
          legend: {
            display: false
          }
        },
        onClick: (event, element) => {
          if (element.length > 0) {
            var index = element[0].index;
            var category = data.labels[index];
            var value = data.datasets[0].data[index];

            var [id] = category.split(" - ")

            const params = new URLSearchParams()
            params.append("category_ids", id)
            params.append("date_start", dates[0])
            params.append("date_end", dates[1])

            window.open("/?" + params.toString())
          }}
      }
    }
  )
}
