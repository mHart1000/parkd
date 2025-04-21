<template>
  <q-dialog v-model="show">
    <q-card style="min-width: 400px">
      <q-card-section>
        <div class="text-h6">Parking Rules</div>
      </q-card-section>

      <q-card-section>
        <q-list bordered>
          <q-item v-for="(rule, index) in rules" :key="index">
            <q-item-section>
              {{ formatRule(rule) }}
            </q-item-section>
            <q-item-section side>
              <q-btn dense flat icon="edit" @click="editRule(index)" />
              <q-btn dense flat icon="delete" color="negative" @click="removeRule(index)" />
            </q-item-section>
          </q-item>
        </q-list>

        <q-separator class="q-my-md" />

        <q-form @submit.prevent="addRule">
          <q-select v-model="form.day_of_week" :options="days" label="Day of Week" />
          <q-select v-model="form.ordinal" :options="ordinals" label="Ordinal" multiple use-chips />
          <q-input v-model="form.start_time" label="Start Time" type="time" />
          <q-input v-model="form.end_time" label="End Time" type="time" />
          <q-input v-model="form.day_of_month" label="Day of Month" type="number" />
          <q-select v-model="form.even_odd" :options="['even', 'odd']" label="Day Parity" />
          <q-input v-model="form.start_date" label="Start Date" type="date" />
          <q-input v-model="form.end_date" label="End Date" type="date" />

          <q-btn class="q-mt-md" type="submit" label="Add Rule" color="primary" />
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
    modelValue: Boolean
  },
  emits: ['update:modelValue', 'save'],
  data () {
    return {
      show: this.modelValue,
      rules: [],
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
    }
  },
  methods: {
    addRule () {
      this.rules.push({ ...this.form })
      this.resetForm()
    },
    editRule (index) {
      this.form = { ...this.rules[index] }
      this.rules.splice(index, 1)
    },
    removeRule (index) {
      this.rules.splice(index, 1)
    },
    resetForm () {
      this.form = {
        day_of_week: null,
        ordinal: [],
        start_time: '',
        end_time: '',
        day_of_month: null,
        even_odd: null,
        start_date: '',
        end_date: ''
      }
    },
    saveRules () {
      this.$emit('save', this.rules)
      this.show = false
    },
    formatRule (rule) {
      const parts = []
      if (rule.ordinal.length && rule.day_of_week) parts.push(`${rule.ordinal.join(' & ')} ${rule.day_of_week}`)
      if (rule.day_of_month) parts.push(`on day ${rule.day_of_month}`)
      if (rule.even_odd) parts.push(`on ${rule.even_odd} days`)
      if (rule.start_time && rule.end_time) parts.push(`${rule.start_time} to ${rule.end_time}`)
      if (rule.start_date || rule.end_date) parts.push(`[${rule.start_date || '...'} to ${rule.end_date || '...'}]`)
      return parts.join(', ')
    }
  }
}
</script>
