(ns user
  (:require ["hardhat" :as hre]
            [cljs.core.async :refer [go timeout go-loop] :as async]
            [cljs.core.async.interop :refer-macros [<p!]]))


(def fs (js/require "fs"))

(def ethers (.-ethers hre))
(def providers (.-providers ethers))


(def utils (.-utils ethers))

;; Local Provider
(def local-provider (new (.-JsonRpcProvider providers)))

;; Local Wallet
(def local-wallet (new (.-Wallet ethers)
                       "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" local-provider))


(defn compile-all!
  "Compile all contracts within the contracts directory"
  []
  (.then (.run hre "compile")
         #(js/console.log %)))


(defn extract-artifact!
  "Extract the abi from the compiled artifact on the given path"
  [path]
  (->> (.readFileSync fs path "utf-8")
       (.parse js/JSON)
       (js->clj)))

(defn abi [path]
  (get (extract-artifact! path)
       "abi"
       "ABI not found"))

(defn bytecode [path]
  (get (extract-artifact! path)
       "bytecode"
       "Bytecode not found"))


(def contracts
  {:lottery         "./artifacts/contracts/Lottrey.sol/Lottery.json"
   :link            "./artifacts/contracts/tests/LinkToken.sol/LinkToken.json"
   :v3-aggregator   "./artifacts/contracts/tests/MockV3Aggregator.sol/MockV3Aggregator.json"
   :vrf-coordinator "./artifacts/contracts/tests/VRFCoordinatorMock.sol/VRFCoordinatorMock.json"})


(defn get-contract!
  [addr abi wallet]
  (new (.-Contract ethers) addr (clj->js abi) wallet))

(defn contract [contract-key wallet]
  (let [path (get contracts contract-key)]
    (new (.-ContractFactory ethers)
         (clj->js (abi path))
         (bytecode path)
         wallet)))


(defn get-event-arg
  [response ename n]
  (let [event (->> (get (js->clj response) "events")
                   (filter #(= (get % "event") ename))
                   (first))]
    (nth (get event "args") n)))


(defn main
  []
  (prn "Welcome to VRF Lottery!"))



;; Chainlink Lottery Example (Free Code Camp Tutorial)
(comment

  (def lottery-contract (atom {}))

  (async/take!
   (go
     (let [fee      "100000000000000000"
           key-hash "0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311"

           ;; mock contracts

           link-contract      (<p! (.deploy (contract :link local-wallet)))
           link-contract-addr (.-address link-contract)

           ;; coordinator
           vrf-coordinator      (<p! (.deploy (contract :vrf-coordinator local-wallet)
                                              link-contract-addr))
           vrf-coordinator-addr (.-address vrf-coordinator)

           ;; aggregator
           aggregator      (<p! (.deploy (contract :v3-aggregator local-wallet) 8 "100000000000000000"))
           aggregator-addr (.-address aggregator)

           ;; lottery
           lottery (<p! (.deploy (contract :lottery local-wallet)
                                 aggregator-addr
                                 vrf-coordinator-addr
                                 link-contract-addr
                                 fee
                                 key-hash))]
       (do
         (reset! lottery-contract {:lottery         lottery
                                   :vrf-coordinator vrf-coordinator
                                   :link            link-contract})
         #_(<p! (.startLottery lottery (js-obj "gasLimit" 800000)))
         #_(.toString (<p! (.getEntranceFee lottery))))))
   #(.log js/console %))

  ;;
  (async/take!
   (go

     ;; start lottery
     (<p! (.startLottery (:lottery @lottery-contract)))

     ;; check state
     (<p! (.lottery_state (:lottery @lottery-contract)))

     ;; send the link tokens from deployer (my wallet addr) to lottery contract
     (<p! (.transfer (:link @lottery-contract)
                     (.-address (:lottery @lottery-contract))
                     "100000000000000000"))

     ;; enter lottery
     (<p! (.enter (:lottery @lottery-contract)
                  (clj->js {:value (str (* 0.1 (.pow js/Math 10 18)))})))

     (let [lottery-end-resp (<p! (.endLottery (:lottery @lottery-contract)
                                              (js-obj "gasLimit" 800000)))
           rec (<p! (.wait lottery-end-resp))
           request-id (get-event-arg rec "RequestedRandomness" 0)]

       ;; TODO:  make the consumerBase call fulfillRandomness
       (<p! (.callBackWithRandomness (:vrf-coordinator @lottery-contract)
                                     request-id
                                     777
                                     (.-address (:lottery @lottery-contract)))))

     (<p! (.lottery_state (:lottery @lottery-contract)
                          (js-obj "gasLimit" 800000))))

   #(.log js/console %))


  (async/take!
   (go
     (<p! (.recentWinner (:lottery @lottery-contract)
                         (js-obj "gasLimit" 800000))))
   #(.log js/console  %))



  )
