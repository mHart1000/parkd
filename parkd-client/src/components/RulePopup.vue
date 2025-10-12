<template>
  <q-dialog v-model="show">
    <q-card style="min-width: 400px">
      <q-card-section>
        <div class="text-h6">Parking Rules</div>
        <div v-if="streetName || streetDirection || address || city" class="q-mt-sm q-mb-sm">
          <div v-if="streetName"><b>Street:</b> {{ streetName }}</div>
          <div v-if="streetDirection"><b>Direction:</b> {{ streetDirection }}</div>
          <div v-if="address"><b>Address:</b> {{ address }}</div>
          <div v-if="city"><b>City:</b> {{ city }}</div>
        </div>
      </q-card-section>

      <q-card-section>
        <q-form>
          <q-select v-model="form.day_of_week" :options="days" label="Day of Week" />
          <q-select v-model="form.ordinal" :options="ordinals" label="Ordinal" multiple use-chips />
          <q-input v-model="form.start_time" label="Start Time" type="time" />
          <q-input v-model="form.end_time" label="End Time" type="time" />
          <q-input v-model="form.day_of_month" label="Day of Month" type="number" />
          <q-select v-model="form.even_odd" :options="['even', 'odd']" label="Even or Odd days of the month" />
          <q-input v-model="form.start_date" label="Start Date" type="date" />
          <q-input v-model="form.end_date" label="End Date" type="date" />
        </q-form>
      </q-card-section>

      <q-card-actions align="right">
        <q-btn flat label="Cancel" v-close-popup />
        <q-btn label="Save" color="primary" @click="saveRules" />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script>
export default {
  name: 'RulePopup',
  props: {
    modelValue: Boolean,
    rules: Array,
    streetName: {
      type: String,
      default: ''
    },
    streetDirection: {
      type: String,
      default: ''
    },
    address: {
      type: String,
      default: ''
    },
    city: {
      type: String,
      default: ''
    }
  },
  emits: ['update:modelValue', 'save'],
  data () {
    return {
      show: this.modelValue,
      form: {
        day_of_week: null,
        ordinal: [],
        start_time: '',
        end_time: '',
        day_of_month: null,
        even_odd: null,
        start_date: '',
        end_date: ''
      },
      days: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
      ordinals: [1, 2, 3, 4, 5]
    }
  },
  watch: {
    modelValue (val) {
      this.show = val
    },
    show (val) {
      this.$emit('update:modelValue', val)
    },
    rules: {
      handler (newRules) {
        this.localRules = [...newRules]
      },
      immediate: true
    }
  },
  methods: {
    saveRules () {
      this.$emit('save', { ...this.form })
      this.show = false
    }
  }
}
</script>
