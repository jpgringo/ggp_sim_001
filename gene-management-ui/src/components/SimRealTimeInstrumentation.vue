<script>
import {defineComponent} from "vue";
import {SciChartSurface, NumericAxis} from "scichart";

async function initSciChart() {
  const {wasmContext, sciChartSurface} = await SciChartSurface.create("scichart-root");
  sciChartSurface.xAxes.add(new NumericAxis(wasmContext));
  sciChartSurface.yAxes.add(new NumericAxis(wasmContext));
  return sciChartSurface;
}

export default defineComponent({
  name: "SimRealTimeInstrumentation",
  data() {
    return {
      chartInitializationPromise: undefined,
    };
  },
  mounted() {
    this.chartInitializationPromise = initSciChart();
  },
  beforeUnmount() {
    this.chartInitializationPromise.then(sciChartSurface => {
      sciChartSurface.delete();
    });
  },
})
</script>

<template>
  <div class="instrumentation real-time">
    <p>Real-time instrumentation</p>
    <div id="scichart-root" style="width: 600px; height: 400px;"></div>
  </div>
</template>

<style scoped>

</style>
