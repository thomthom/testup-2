/*******************************************************************************
 *
 * Copyright 2013-2018 Trimble Inc.
 * License: The MIT License (MIT)
 *
 ******************************************************************************/

"use strict";

import Vue from "vue";


/* TODO(thomthom): Move to separate module. (See SUbD) */
function sketchupErrorHandler(error, vm, info) {
  let data = {
    'message' : `Vue Error (${info}): ${error.message}`,
    'backtrace' : error.backtrace,
    'user-agent': navigator.userAgent,
    'document-mode': document.documentMode
  };
  sketchup.js_error(data);
  console.error(data.message);
  console.error(error);
}
Vue.config.errorHandler = sketchupErrorHandler;
// TODO(thomthom): Look into also hooking up warnHandler.
// https://vuejs.org/v2/api/#warnHandler

window.onerror = function(message, file, line, column, error) {
  try
  {
    // Not all browsers pass along the error object. Without that it's not
    // possible to get full backtrace.
    // http://blog.bugsnag.com/js-stacktraces
    var backtrace = [];
    if (error && error.stack)
    {
      backtrace = String(error.stack).split("\n");
    }
    else
    {
      backtrace = [file + ':' + line + ':' + column];
    }
    var data = {
      'message' : message,
      'backtrace' : backtrace,
      'user-agent': navigator.userAgent,
      'document-mode': document.documentMode
    };
    sketchup.js_error(data);
  }
  catch (error)
  {
    debugger;
    throw error;
  }
};


import SUButton from "./components/su-button.vue";
import SUCheckbox from "./components/su-checkbox.vue";
import SUPanelGroup from "./components/su-panel-group.vue";
import SUPanel from "./components/su-panel.vue";
import SUScrollable from "./components/su-scrollable.vue";
import SUStatusbar from "./components/su-statusbar.vue";
import SUTabs from "./components/su-tabs.vue";
import SUTab from "./components/su-tab.vue";
import SUToolbar from "./components/su-toolbar.vue";
import TUTestCase from "./components/tu-test-case.vue";
import TUTestSuite from "./components/tu-test-suite.vue";


window.app = new Vue({
  el: '#app',
  data: {
    test_suites: [],
    activeTestSuiteIndex: 0,
    statusBarText: '',
  },
  methods: {
    configure(config) {
      console.log('configure', config);
      let test_suite_title = config.active_tab;
      // this.test_suites[this.activeTestSuiteIndex];
      let index = this.test_suites.findIndex((test_suite) => {
        return test_suite.title == test_suite_title;
      });
      console.log('tab index:', index);
      this.activeTestSuiteIndex = index >= 0 ? index : 0;
    },
    discover(discoveries) {
      console.log('discover');
      this.test_suites = discoveries;
      this.statusBarText = `
        ${ this.num_test_suites } test suites,
        ${ this.num_test_cases } test cases,
        ${ this.num_tests - this.num_tests_missing } tests discovered,
        ${ this.num_tests_missing } tests missing
      `;
    },
    rediscover(discoveries) {
      console.log('rediscover');
      this.test_suites = discoveries;
      this.statusBarText = `
        ${ this.num_test_suites } test suites,
        ${ this.num_test_cases } test cases,
        ${ this.num_tests - this.num_tests.missing } tests discovered,
        ${ this.num_tests.missing } tests missing
      `;
    },
    update_results(test_suite) {
      console.log('update_results', this.activeTestSuiteIndex);
      // let tsi = this.test_suites.find((ts) => {
      //   return ts.title == test_suite.title;
      // });
      // let index = this.test_suites.indexOf(tsi);
      // this.test_suites[index] = test_suite;
      // TODO: Find a better way to get the test_suite index. Don't rely on the
      //       active tab index.
      // TODO: Update coverage
      this.test_suites[this.activeTestSuiteIndex].test_cases = test_suite.test_cases;
      // Update statusbar.
      let stats = this.test_suite_stats(test_suite);
      let total_time_formatted = stats.total_time.toFixed(3) + 's';
      this.statusBarText = `
        ${ stats.tests } tests from test suite ${ test_suite.title }
        run in ${ total_time_formatted }.
        ${ stats.passed } passed,
        ${ stats.failed } failed,
        ${ stats.errors } errors,
        ${ stats.skipped } skipped
      `;
    },
    selectTestSuite(test_suite, enabled) {
      for (let test_case of test_suite.test_cases) {
        test_case.enabled = enabled;
        for (let test of test_case.tests) {
          test.enabled = enabled
        }
      }
    },
    runTests() {
      let test_suite = this.test_suites[this.activeTestSuiteIndex];
      sketchup.runTests(test_suite);
    },
    discoverTests() {
      // TODO: This appear to sometimes cause crashes.
      // sketchup.discoverTests(this.test_suites);
      // Workaround is to convert to a JSON string and have Ruby perform the
      // parsing itself. Might be a bug in the SketchUp code that converts the
      // callback data to Ruby objects.
      // Additionally, I don't think SU2016 supported all the types needed to
      // pass an object back as a Hash to Ruby.
      let json = JSON.stringify(this.test_suites);
      sketchup.discoverTests(json);
    },
    reRun() {
      sketchup.reRunTests();
    },
    changeTestSuite(index) {
      this.activeTestSuiteIndex = index;
      sketchup.changeActiveTestSuite(this.active_test_suite.title);
    },
    test_suite_stats(test_suite) {
      let data = {
        tests: 0,
        passed: 0,
        failed: 0,
        errors: 0,
        skipped: 0,
        missing: 0,
        total_time: 0,
      };
      if (test_suite) {
        for (let test_case of test_suite.test_cases) {
          data.tests += test_case.tests.length;
          for (let test of test_case.tests) {
            data.missing += test.missing ? 1 : 0;
            if (!test.result) continue;
            data.passed += test.result.passed ? 1 : 0;
            data.failed += test.result.failed ? 1 : 0;
            data.errors += test.result.error ? 1 : 0;
            data.skipped += test.result.skipped ? 1 : 0;
            data.total_time += test.result.run_time;
          }
        }
      }
      return data;
    },
  },
  computed: {
    num_test_suites: function () {
      return this.test_suites.length;
    },
    num_test_cases: function () {
      let num = 0;
      for (let test_suite of this.test_suites) {
        num += test_suite.test_cases.length;
      }
      return num;
    },
    num_tests: function () {
      let num = 0;
      for (let test_suite of this.test_suites) {
        for (let test_case of test_suite.test_cases) {
          num += test_case.tests.length;
        }
      }
      return num;
    },
    num_tests_missing: function () {
      let num = 0;
      for (let test_suite of this.test_suites) {
        for (let test_case of test_suite.test_cases) {
          for (let test of test_case.tests) {
            if (test.missing) num += 1;
          }
        }
      }
      return num;
    },
    active_test_suite() {
      console.log('active_test_suite');
      return this.test_suites[this.activeTestSuiteIndex];
    },
    active_test_suite_stats() {
      console.log('active_test_suite_stats');
      return this.test_suite_stats(this.active_test_suite);
    },
  },
  mounted() {
    sketchup.ready();
  },
  components: {
    'su-button': SUButton,
    'su-panel': SUPanel,
    'su-panel-group': SUPanelGroup,
    'su-scrollable': SUScrollable,
    'su-statusbar': SUStatusbar,
    'su-tabs': SUTabs,
    'su-tab': SUTab,
    'su-toolbar': SUToolbar,
    'tu-test-case': TUTestCase,
    'tu-test-suite': TUTestSuite,
  },
});