module SimpleBank

(* F* model of src/SimpleBank.sol.
   Automated deductive verification: lemmas discharged by Z3.
   Abstract vault, not an EVM interpreter.
   Wei is nat. Solidity uint256 overflow is not modelled. *)

let address = nat
let wei = nat

noeq type state = {
  credit: address -> Tot wei;
  reserves: wei;
  rejecting: address -> Tot bool;
  held: address -> Tot wei;
}

let deposit (s: state) (sender: address) (value: wei) : state =
  { s with
    credit = (fun a -> if a = sender then s.credit sender + value else s.credit a);
    reserves = s.reserves + value }

let withdraw_ok (s: state) (sender: address) (amount: wei) : bool =
  amount <= s.credit sender && not (s.rejecting sender) && amount <= s.reserves

let withdraw_state (s: state) (sender: address) (amount: wei)
  : Pure state
    (requires withdraw_ok s sender amount)
    (ensures fun _ -> True) =
  { s with
    credit = (fun a -> if a = sender then s.credit sender - amount else s.credit a);
    reserves = s.reserves - amount;
    held = (fun a -> if a = sender then s.held sender + amount else s.held a) }

let rec mem (x: address) (xs: list address) : Tot bool =
  match xs with
  | [] -> false
  | y :: tl -> x = y || mem x tl

let rec nodup (xs: list address) : Tot bool =
  match xs with
  | [] -> true
  | y :: tl -> not (mem y tl) && nodup tl

let rec sum_credits (credit: address -> Tot wei) (xs: list address) : Tot nat =
  match xs with
  | [] -> 0
  | a :: tl -> credit a + sum_credits credit tl

let solvent (s: state) (xs: list address) : bool =
  nodup xs && s.reserves = sum_credits s.credit xs

let init (rejecting: address -> Tot bool) : state =
  { credit = (fun _ -> 0); reserves = 0; rejecting = rejecting; held = (fun _ -> 0) }

let p1_deposit_credits_caller_and_reserves (s: state) (sender: address) (value: wei)
  : Lemma ((deposit s sender value).credit sender = s.credit sender + value
        /\ (deposit s sender value).reserves = s.reserves + value
        /\ (deposit s sender value).held == s.held
        /\ (deposit s sender value).rejecting == s.rejecting)
  = ()

let p3_deposit_preserves_other (s: state) (sender other: address) (value: wei)
  : Lemma (requires sender <> other)
          (ensures (deposit s sender value).credit other = s.credit other)
  = ()

let p3_withdraw_preserves_other (s: state) (sender other: address) (amount: wei)
  : Lemma (requires withdraw_ok s sender amount /\ sender <> other)
          (ensures (withdraw_state s sender amount).credit other = s.credit other
                /\ (withdraw_state s sender amount).held other = s.held other)
  = ()

let p2_withdraw_success_effect (s: state) (sender: address) (amount: wei)
  : Lemma (requires withdraw_ok s sender amount)
          (ensures (let s' = withdraw_state s sender amount in
                    s'.credit sender = s.credit sender - amount
                 /\ s'.reserves = s.reserves - amount
                 /\ s'.held sender = s.held sender + amount))
  = ()

let p5_rejecting_reverts (s: state) (sender: address) (amount: wei)
  : Lemma (requires s.rejecting sender)
          (ensures not (withdraw_ok s sender amount))
  = ()

let rec sum_not_mem (credit: address -> Tot wei) (xs: list address) (sender: address) (newv: wei)
  : Lemma (requires not (mem sender xs))
          (ensures sum_credits (fun a -> if a = sender then newv else credit a) xs
                 = sum_credits credit xs)
  = match xs with
    | [] -> ()
    | _ :: tl -> sum_not_mem credit tl sender newv

let rec credit_le_sum (credit: address -> Tot wei) (xs: list address) (sender: address)
  : Lemma (requires mem sender xs)
          (ensures credit sender <= sum_credits credit xs)
  = match xs with
    | [] -> ()
    | a :: tl ->
      if a = sender then ()
      else credit_le_sum credit tl sender

let rec sum_replace (credit: address -> Tot wei) (xs: list address) (sender: address) (newv: wei)
  : Lemma (requires mem sender xs /\ nodup xs)
          (ensures sum_credits (fun a -> if a = sender then newv else credit a) xs
                 = sum_credits credit xs + newv - credit sender)
  = match xs with
    | [] -> ()
    | a :: tl ->
      if a = sender then sum_not_mem credit tl sender newv
      else sum_replace credit tl sender newv

let p4_deposit_preserves_solvency (s: state) (xs: list address) (sender: address) (value: wei)
  : Lemma (requires solvent s xs /\ mem sender xs)
          (ensures solvent (deposit s sender value) xs)
  = sum_replace s.credit xs sender (s.credit sender + value)

let p4_withdraw_preserves_solvency (s: state) (xs: list address) (sender: address) (amount: wei)
  : Lemma (requires solvent s xs /\ mem sender xs /\ withdraw_ok s sender amount)
          (ensures solvent (withdraw_state s sender amount) xs)
  = credit_le_sum s.credit xs sender;
    sum_replace s.credit xs sender (s.credit sender - amount)

let p2_succeeds_iff_on_solvent (s: state) (xs: list address) (sender: address) (amount: wei)
  : Lemma (requires solvent s xs /\ mem sender xs)
          (ensures withdraw_ok s sender amount
               <==> (amount <= s.credit sender && not (s.rejecting sender)))
  = if amount <= s.credit sender && not (s.rejecting sender)
    then credit_le_sum s.credit xs sender
    else ()

let rec sum_zero (xs: list address)
  : Lemma (sum_credits (fun _ -> 0) xs = 0)
  = match xs with
    | [] -> ()
    | _ :: tl -> sum_zero tl

let p4_init_solvent (rejecting: address -> Tot bool) (xs: list address)
  : Lemma (requires nodup xs)
          (ensures solvent (init rejecting) xs)
  = sum_zero xs

type op =
  | DepositOp : address -> wei -> op
  | WithdrawOp : address -> wei -> op

let sender_of (op: op) : address =
  match op with
  | DepositOp sender _ -> sender
  | WithdrawOp sender _ -> sender

let step (s: state) (op: op) : state =
  match op with
  | DepositOp sender value -> deposit s sender value
  | WithdrawOp sender amount ->
    if withdraw_ok s sender amount then withdraw_state s sender amount else s

let rec run (s: state) (ops: list op) : Tot state (decreases ops) =
  match ops with
  | [] -> s
  | o :: tl -> run (step s o) tl

let rec senders_in (ops: list op) (xs: list address) : Tot bool =
  match ops with
  | [] -> true
  | o :: tl -> mem (sender_of o) xs && senders_in tl xs

let step_preserves (s: state) (xs: list address) (op: op)
  : Lemma (requires solvent s xs /\ mem (sender_of op) xs)
          (ensures solvent (step s op) xs)
  = match op with
    | DepositOp sender value -> p4_deposit_preserves_solvency s xs sender value
    | WithdrawOp sender amount ->
      if withdraw_ok s sender amount
      then p4_withdraw_preserves_solvency s xs sender amount
      else ()

let rec p4_run_preserves_solvency (s: state) (xs: list address) (ops: list op)
  : Lemma (requires solvent s xs /\ senders_in ops xs)
          (ensures solvent (run s ops) xs)
          (decreases ops)
  = match ops with
    | [] -> ()
    | o :: tl ->
      step_preserves s xs o;
      p4_run_preserves_solvency (step s o) xs tl

let p4_reachable_solvent (rejecting: address -> Tot bool) (xs: list address) (ops: list op)
  : Lemma (requires nodup xs /\ senders_in ops xs)
          (ensures solvent (run (init rejecting) ops) xs)
  = p4_init_solvent rejecting xs;
    p4_run_preserves_solvency (init rejecting) xs ops

let p2_reachable_withdraw_within_reserves
    (rejecting: address -> Tot bool) (xs: list address) (ops: list op)
    (sender: address) (amount: wei)
  : Lemma (requires nodup xs /\ mem sender xs /\ senders_in ops xs
                  /\ withdraw_ok (run (init rejecting) ops) sender amount)
          (ensures amount <= (run (init rejecting) ops).reserves)
  = let s = run (init rejecting) ops in
    p4_reachable_solvent rejecting xs ops;
    credit_le_sum s.credit xs sender
