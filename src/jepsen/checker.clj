(ns jepsen.checker
  "Validates that a history is correct with respect to some model."
  (:require [clojure.stacktrace :as trace]
            [knossos.core :as knossos]))

(defprotocol Checker
  (check [checker test model history]
         "Verify the history is correct. Returns a map like

         {:valid? true}

         or

         {:valid?    false
          :failed-at [details of specific operations]}

         and maybe there can be some stats about what fraction of requests
         were corrupt, etc."))

(def unbridled-optimism
  "Everything is wonderful!"
  (constantly {:valid? true}))

(def linearizable
  "Validates linearizability with Knossos."
  (reify Checker
    (check [this test model history]
      (let [history'      (knossos/complete history)
            linearizable  (knossos/linearizable-prefix model history')]
        {:valid?                (= history' linearizable)
         :linearizable-prefix   linearizable}))))

(defn check-safe
  "Like check, but wraps exceptions up and returns them as a map like

  {:valid? nil :error \"...\"}"
  [checker test model history]
  (try (check checker test model history)
       (catch Throwable t
         {:valid? false
          :error (with-out-str (trace/print-cause-trace t))})))
