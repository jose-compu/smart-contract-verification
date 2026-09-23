(* SPDX-License-Identifier: Apache-2.0
   The imported interpreter is LGPL-3.0 and is not part of this file.
   See pins.txt. *)

(** Deposit's credit-word update on the academic coq-evm interpreter.

    The fragment is the stack program
      ADD; SWAP1; SSTORE
    with the initial stack [old :: value :: slot :: tail].
    [ADD] is [wplus] (mod 2^256). [SSTORE] writes that word at [slot].

    This is not an execution of [src/SimpleBank.sol]. coq-evm leaves
    [CALL], [SHA3], and [CREATE] as [NotImplemented], and its [SLOAD]
    pushes the loaded word onto the pre-pop stack, so the bytecode of
    [deposit] is not run here. The old credit word is an input. *)

From Coq Require Import List PeanoNat.
Import ListNotations.
Require Import bbv.Word.
Require Import CoqEVM.evmModel.
Import evmModel.

Lemma getStack_setStack :
  forall es st, getStack_ES (setStack_ES es st) = st.
Proof. intros es st. destruct es. reflexivity. Qed.

Lemma getStorage_setStack :
  forall es st, getStorage_ES (setStack_ES es st) = getStorage_ES es.
Proof. intros es st. destruct es. reflexivity. Qed.

Lemma getStack_setStorage :
  forall es st, getStack_ES (setStorage_ES es st) = getStack_ES es.
Proof. intros es st. destruct es. reflexivity. Qed.

Lemma getStorage_setStorage :
  forall es st, getStorage_ES (setStorage_ES es st) = st.
Proof. intros es st. destruct es. reflexivity. Qed.

(** [ADD] replaces the top two words by their [wplus]. *)
Lemma ADD_pushes_wplus :
  forall es a b rest,
    getStack_ES es = a :: b :: rest ->
    length rest < 1024 ->
    addActionPure es =
      inr (setStack_ES (setStack_ES es rest) (wplus a b :: rest)).
Proof.
  intros es a b rest Hstack Hlen.
  unfold addActionPure, flatMap, removeAndReturnFromStackTwoItems,
    pushItemToExecutionStateStack.
  rewrite Hstack. simpl.
  rewrite getStack_setStack.
  unfold runningExecutionWithState.
  rewrite (proj2 (Nat.ltb_lt (length rest) 1024) Hlen).
  reflexivity.
Qed.

(** [SWAP1] exchanges the top two words. The opcode argument is the 4-bit
    immediate 0, and the interpreter swaps index [wordToNat arg + 1]. *)
Lemma SWAP1_exchanges :
  forall es a b rest,
    getStack_ES es = a :: b :: rest ->
    swapActionPure (natToWord 4 0) es = inr (setStack_ES es (b :: a :: rest)).
Proof.
  intros es a b rest Hstack.
  unfold swapActionPure, listSwapWithHead, flatMapO.
  rewrite Hstack. simpl.
  unfold runningExecutionWithState.
  reflexivity.
Qed.

(** [SSTORE] of a missing key writes it. Gas follows this interpreter: 20000. *)
Lemma SSTORE_fresh :
  forall es key value rest,
    getStack_ES es = key :: value :: rest ->
    find key (getStorage_ES es) = None ->
    sstoreActionPure es =
      inr (setStorage_ES (setStack_ES es rest)
             (update (key, value) (getStorage_ES (setStack_ES es rest))),
           20000%nat).
Proof.
  intros es key value rest Hstack Hfind.
  unfold sstoreActionPure, flatMap, removeAndReturnFromStackTwoItems,
    runningExecutionWithState.
  rewrite Hstack. simpl.
  rewrite getStorage_setStack.
  rewrite Hfind. simpl.
  reflexivity.
Qed.

(** [SSTORE] over a nonzero word overwrites it. Gas in this interpreter: 5000. *)
Lemma SSTORE_nonzero :
  forall es key value w rest,
    getStack_ES es = key :: value :: rest ->
    find key (getStorage_ES es) = Some w ->
    weqb w WZero = false ->
    sstoreActionPure es =
      inr (setStorage_ES (setStack_ES es rest)
             (update (key, value) (getStorage_ES (setStack_ES es rest))),
           5000%nat).
Proof.
  intros es key value w rest Hstack Hfind Hnz.
  unfold sstoreActionPure, flatMap, removeAndReturnFromStackTwoItems,
    runningExecutionWithState.
  rewrite Hstack. simpl.
  rewrite getStorage_setStack.
  rewrite Hfind. simpl.
  rewrite Hnz. simpl.
  reflexivity.
Qed.

(** [old :: value :: slot :: tail]  --ADD-->  [sum :: slot :: tail]
    --SWAP1-->  [slot :: sum :: tail]  --SSTORE-->  storage(slot) = sum. *)
Definition credit_word_update (es : ExecutionState)
  : ExecutionResultOr (ExecutionState * nat) :=
  match addActionPure es with
  | inl err => inl err
  | inr es1 =>
      match swapActionPure (natToWord 4 0) es1 with
      | inl err => inl err
      | inr es2 => sstoreActionPure es2
      end
  end.

Theorem deposit_credit_word_fresh :
  forall es old value slot tail,
    getStack_ES es = old :: value :: slot :: tail ->
    find slot (getStorage_ES es) = None ->
    length (slot :: tail) < 1024 ->
    exists es',
      credit_word_update es = inr (es', 20000%nat) /\
      getStack_ES es' = tail /\
      getStorage_ES es' = update (slot, wplus old value) (getStorage_ES es).
Proof.
  intros es old value slot tail Hstack Hfind Hlen.
  set (es1 := setStack_ES (setStack_ES es (slot :: tail)) (wplus old value :: slot :: tail)).
  assert (Hadd : addActionPure es = inr es1).
  { apply ADD_pushes_wplus; assumption. }
  set (es2 := setStack_ES es1 (slot :: wplus old value :: tail)).
  assert (Hswap : swapActionPure (natToWord 4 0) es1 = inr es2).
  { apply SWAP1_exchanges. unfold es1. rewrite getStack_setStack. reflexivity. }
  assert (Hstor1 : getStorage_ES es1 = getStorage_ES es).
  { unfold es1. rewrite getStorage_setStack, getStorage_setStack. reflexivity. }
  assert (Hstack2 : getStack_ES es2 = slot :: wplus old value :: tail).
  { unfold es2. rewrite getStack_setStack. reflexivity. }
  assert (Hstor2 : getStorage_ES es2 = getStorage_ES es).
  { unfold es2. rewrite getStorage_setStack. exact Hstor1. }
  assert (Hs :
    sstoreActionPure es2 =
      inr (setStorage_ES (setStack_ES es2 tail)
             (update (slot, wplus old value) (getStorage_ES (setStack_ES es2 tail))),
           20000%nat)).
  { apply SSTORE_fresh.
    - exact Hstack2.
    - rewrite Hstor2. exact Hfind. }
  unfold credit_word_update. rewrite Hadd, Hswap, Hs.
  eexists. split; [reflexivity|]. split.
  - rewrite getStack_setStorage, getStack_setStack. reflexivity.
  - rewrite getStorage_setStorage, getStorage_setStack, Hstor2. reflexivity.
Qed.

Theorem deposit_credit_word_nonzero :
  forall es old value slot w tail,
    getStack_ES es = old :: value :: slot :: tail ->
    find slot (getStorage_ES es) = Some w ->
    weqb w WZero = false ->
    length (slot :: tail) < 1024 ->
    exists es',
      credit_word_update es = inr (es', 5000%nat) /\
      getStack_ES es' = tail /\
      getStorage_ES es' = update (slot, wplus old value) (getStorage_ES es).
Proof.
  intros es old value slot w tail Hstack Hfind Hnz Hlen.
  set (es1 := setStack_ES (setStack_ES es (slot :: tail)) (wplus old value :: slot :: tail)).
  assert (Hadd : addActionPure es = inr es1).
  { apply ADD_pushes_wplus; assumption. }
  set (es2 := setStack_ES es1 (slot :: wplus old value :: tail)).
  assert (Hswap : swapActionPure (natToWord 4 0) es1 = inr es2).
  { apply SWAP1_exchanges. unfold es1. rewrite getStack_setStack. reflexivity. }
  assert (Hstor1 : getStorage_ES es1 = getStorage_ES es).
  { unfold es1. rewrite getStorage_setStack, getStorage_setStack. reflexivity. }
  assert (Hstack2 : getStack_ES es2 = slot :: wplus old value :: tail).
  { unfold es2. rewrite getStack_setStack. reflexivity. }
  assert (Hstor2 : getStorage_ES es2 = getStorage_ES es).
  { unfold es2. rewrite getStorage_setStack. exact Hstor1. }
  assert (Hs :
    sstoreActionPure es2 =
      inr (setStorage_ES (setStack_ES es2 tail)
             (update (slot, wplus old value) (getStorage_ES (setStack_ES es2 tail))),
           5000%nat)).
  { eapply SSTORE_nonzero.
    - exact Hstack2.
    - rewrite Hstor2. exact Hfind.
    - exact Hnz. }
  unfold credit_word_update. rewrite Hadd, Hswap, Hs.
  eexists. split; [reflexivity|]. split.
  - rewrite getStack_setStorage, getStack_setStack. reflexivity.
  - rewrite getStorage_setStorage, getStorage_setStack, Hstor2. reflexivity.
Qed.

Redirect "assumptions-deposit.txt" Print Assumptions deposit_credit_word_fresh.
Redirect "assumptions-nonzero.txt" Print Assumptions deposit_credit_word_nonzero.
Redirect "assumptions-add.txt" Print Assumptions ADD_pushes_wplus.
