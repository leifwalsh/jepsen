(ns jepsen.system.rabbitmq-test
  (:use jepsen.system.rabbitmq
        jepsen.core
        jepsen.core-test
        clojure.test
        clojure.pprint)
  (:require [jepsen.os.debian :as debian]
            [jepsen.model     :as model]
            [jepsen.generator :as gen]
            [jepsen.nemesis   :as nemesis]))

(deftest rabbit-test
  (let [test (run! (assoc noop-test
                          :os         debian/os
                          :db         db
                          :client     (queue-client)
                          :nemesis    (nemesis/simple-partition)
                          :model      (model/unordered-queue)
                          :generator  (->> gen/queue
                                           (gen/finite-count 60)
                                           (gen/delay 10)
                                           (gen/nemesis
                                             (gen/start-stop 15 60)))))]

    (is (:valid? (:results test)))
    (pprint test)))
