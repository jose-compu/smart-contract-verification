theory SimpleBank
  imports Main
begin

text \<open>
  Isabelle/HOL model of src/SimpleBank.sol.
  Credits, reserves, a rejecting set, and a payout purse. Not an EVM interpreter.
  Wei is nat (unbounded). Solidity uint256 overflow is not modelled.
\<close>

type_synonym addr = nat
type_synonym wei = nat

record state =
  credit :: "addr \<Rightarrow> wei"
  reserves :: wei
  rejecting :: "addr set"
  held :: "addr \<Rightarrow> wei"

definition deposit :: "state \<Rightarrow> addr \<Rightarrow> wei \<Rightarrow> state" where
  "deposit s sender v =
     s\<lparr>credit := (credit s)(sender := credit s sender + v),
       reserves := reserves s + v\<rparr>"

definition withdraw_ok :: "state \<Rightarrow> addr \<Rightarrow> wei \<Rightarrow> bool" where
  "withdraw_ok s sender a \<longleftrightarrow>
     a \<le> credit s sender \<and> sender \<notin> rejecting s \<and> a \<le> reserves s"

definition withdraw :: "state \<Rightarrow> addr \<Rightarrow> wei \<Rightarrow> state" where
  "withdraw s sender a =
     s\<lparr>credit := (credit s)(sender := credit s sender - a),
       reserves := reserves s - a,
       held := (held s)(sender := held s sender + a)\<rparr>"

fun sum_credits :: "(addr \<Rightarrow> wei) \<Rightarrow> addr list \<Rightarrow> wei" where
  "sum_credits m [] = 0"
| "sum_credits m (a # xs) = m a + sum_credits m xs"

definition support_closed :: "(addr \<Rightarrow> wei) \<Rightarrow> addr list \<Rightarrow> bool" where
  "support_closed m xs \<longleftrightarrow> (\<forall>a. m a \<noteq> 0 \<longrightarrow> a \<in> set xs)"

definition solvent :: "state \<Rightarrow> addr list \<Rightarrow> bool" where
  "solvent s xs \<longleftrightarrow>
     distinct xs \<and> support_closed (credit s) xs \<and> reserves s = sum_credits (credit s) xs"

definition init :: "addr set \<Rightarrow> state" where
  "init R = \<lparr>credit = (\<lambda>_. 0), reserves = 0, rejecting = R, held = (\<lambda>_. 0)\<rparr>"

datatype op =
  DepositOp addr wei
| WithdrawOp addr wei

fun op_sender :: "op \<Rightarrow> addr" where
  "op_sender (DepositOp a _) = a"
| "op_sender (WithdrawOp a _) = a"

fun step :: "state \<Rightarrow> op \<Rightarrow> state" where
  "step s (DepositOp a v) = deposit s a v"
| "step s (WithdrawOp a k) = (if withdraw_ok s a k then withdraw s a k else s)"

fun run :: "state \<Rightarrow> op list \<Rightarrow> state" where
  "run s [] = s"
| "run s (op # ops) = run (step s op) ops"

definition senders_in :: "op list \<Rightarrow> addr list \<Rightarrow> bool" where
  "senders_in ops xs \<longleftrightarrow> (\<forall>op \<in> set ops. op_sender op \<in> set xs)"

lemma fun_upd_lambda: "f(a := v) = (\<lambda>b. if b = a then v else f b)"
  by (rule ext) simp

lemma sum_zero: "sum_credits (\<lambda>_. 0) xs = 0"
  by (induction xs) simp_all

lemma sum_not_mem:
  "a \<notin> set xs \<Longrightarrow> sum_credits (m(a := v)) xs = sum_credits m xs"
  by (induction xs) auto

lemma credit_le_sum:
  "\<lbrakk>distinct xs; a \<in> set xs\<rbrakk> \<Longrightarrow> m a \<le> sum_credits m xs"
proof (induction xs)
  case Nil
  then show ?case by simp
next
  case (Cons h xs)
  then show ?case by (cases "h = a") auto
qed

lemma sum_plus:
  "\<lbrakk>distinct xs; a \<in> set xs\<rbrakk> \<Longrightarrow>
     sum_credits (m(a := m a + v)) xs = sum_credits m xs + v"
proof (induction xs)
  case Nil
  then show ?case by simp
next
  case (Cons h xs)
  show ?case
  proof (cases "h = a")
    case True
    with Cons.prems have "a \<notin> set xs" by auto
    then have "sum_credits (m(a := m a + v)) xs = sum_credits m xs"
      by (simp add: sum_not_mem)
    with True show ?thesis by (simp add: fun_upd_lambda)
  next
    case False
    with Cons.prems have "a \<in> set xs" "distinct xs" by auto
    with False Cons.IH show ?thesis by simp
  qed
qed

lemma sum_minus:
  "\<lbrakk>distinct xs; a \<in> set xs; k \<le> m a\<rbrakk> \<Longrightarrow>
     sum_credits (m(a := m a - k)) xs = sum_credits m xs - k"
proof (induction xs)
  case Nil
  then show ?case by simp
next
  case (Cons h xs)
  show ?case
  proof (cases "h = a")
    case True
    with Cons.prems have "a \<notin> set xs" "k \<le> m a" by auto
    then have "sum_credits (m(a := m a - k)) xs = sum_credits m xs"
      by (simp add: sum_not_mem)
    with True \<open>k \<le> m a\<close> show ?thesis
      by (simp add: fun_upd_lambda diff_add_assoc)
  next
    case False
    with Cons.prems have "a \<in> set xs" "distinct xs" "k \<le> m a" by auto
    then have "k \<le> sum_credits m xs"
      by (meson credit_le_sum order_trans)
    with False Cons.IH Cons.prems show ?thesis by simp
  qed
qed

lemma p1_credit:
  "credit (deposit s sender v) sender = credit s sender + v"
  by (simp add: deposit_def)

lemma p1_reserves:
  "reserves (deposit s sender v) = reserves s + v"
  by (simp add: deposit_def)

lemma p3_deposit:
  "other \<noteq> sender \<Longrightarrow> credit (deposit s sender v) other = credit s other"
  by (simp add: deposit_def)

lemma p3_withdraw:
  "other \<noteq> sender \<Longrightarrow> credit (withdraw s sender a) other = credit s other"
  by (simp add: withdraw_def)

lemma p2_success_effect:
  assumes "withdraw_ok s sender a"
  shows "credit (withdraw s sender a) sender = credit s sender - a"
    and "reserves (withdraw s sender a) = reserves s - a"
    and "held (withdraw s sender a) sender = held s sender + a"
  using assms by (simp_all add: withdraw_def withdraw_ok_def)

lemma p5_not_ok:
  "sender \<in> rejecting s \<Longrightarrow> \<not> withdraw_ok s sender a"
  by (simp add: withdraw_ok_def)

lemma p5_step_unchanged:
  "sender \<in> rejecting s \<Longrightarrow> step s (WithdrawOp sender a) = s"
  by (simp add: p5_not_ok)

lemma credit_le_reserves:
  assumes "solvent s xs"
  shows "credit s sender \<le> reserves s"
proof (cases "sender \<in> set xs")
  case True
  with assms show ?thesis
    by (simp add: solvent_def credit_le_sum)
next
  case False
  with assms have "credit s sender = 0"
    by (auto simp: solvent_def support_closed_def)
  then show ?thesis by simp
qed

lemma p2_succeeds_iff:
  assumes "solvent s xs"
  shows "withdraw_ok s sender a \<longleftrightarrow> a \<le> credit s sender \<and> sender \<notin> rejecting s"
  using assms credit_le_reserves
  by (auto simp: withdraw_ok_def order_trans)

lemma support_deposit:
  assumes "support_closed (credit s) xs" "sender \<in> set xs"
  shows "support_closed (credit (deposit s sender v)) xs"
  using assms by (auto simp: support_closed_def deposit_def)

lemma support_withdraw:
  assumes "support_closed (credit s) xs" "withdraw_ok s sender a"
  shows "support_closed (credit (withdraw s sender a)) xs"
proof -
  have "sender \<in> set xs \<or> a = 0"
    using assms by (auto simp: support_closed_def withdraw_ok_def)
  then show ?thesis
    using assms by (auto simp: support_closed_def withdraw_def withdraw_ok_def)
qed

lemma p4_deposit:
  assumes "solvent s xs" "sender \<in> set xs"
  shows "solvent (deposit s sender v) xs"
proof -
  have "reserves (deposit s sender v) = sum_credits (credit (deposit s sender v)) xs"
    using assms by (simp add: solvent_def deposit_def p1_reserves sum_plus)
  moreover have "support_closed (credit (deposit s sender v)) xs"
    using assms by (simp add: solvent_def support_deposit)
  moreover have "distinct xs"
    using assms by (simp add: solvent_def)
  ultimately show ?thesis by (simp add: solvent_def)
qed

lemma p4_withdraw:
  assumes "solvent s xs"
  shows "solvent (step s (WithdrawOp sender a)) xs"
proof (cases "withdraw_ok s sender a")
  case False
  with assms show ?thesis by simp
next
  case True
  have inn: "sender \<in> set xs \<or> a = 0"
    using assms True by (auto simp: solvent_def support_closed_def withdraw_ok_def)
  have "reserves (withdraw s sender a) = sum_credits (credit (withdraw s sender a)) xs"
  proof (cases "sender \<in> set xs")
    case True
    with assms \<open>withdraw_ok s sender a\<close> show ?thesis
      by (simp add: solvent_def withdraw_def withdraw_ok_def sum_minus)
  next
    case False
    with inn have "a = 0" by simp
    with False assms show ?thesis
      by (simp add: solvent_def withdraw_def sum_not_mem)
  qed
  moreover have "support_closed (credit (withdraw s sender a)) xs"
    using assms True by (simp add: solvent_def support_withdraw)
  moreover have "distinct xs"
    using assms by (simp add: solvent_def)
  ultimately show ?thesis using True by (simp add: solvent_def)
qed

lemma step_preserves:
  assumes sol: "solvent s xs" and inn: "op_sender op \<in> set xs"
  shows "solvent (step s op) xs"
proof (cases op)
  case (DepositOp a v)
  with inn have "a \<in> set xs" by simp
  with sol have "solvent (deposit s a v) xs" by (rule p4_deposit)
  with DepositOp show ?thesis by (simp add: step.simps)
next
  case (WithdrawOp a k)
  from sol have "solvent (step s (WithdrawOp a k)) xs" by (rule p4_withdraw)
  with WithdrawOp show ?thesis by metis
qed

lemma p4_init:
  "distinct xs \<Longrightarrow> solvent (init R) xs"
  by (simp add: solvent_def support_closed_def init_def sum_zero)

lemma p4_run:
  assumes "solvent s xs" "senders_in ops xs"
  shows "solvent (run s ops) xs"
  using assms
proof (induction ops arbitrary: s)
  case Nil
  then show ?case by simp
next
  case (Cons op ops)
  then have "solvent (step s op) xs"
    by (simp add: senders_in_def step_preserves)
  with Cons show ?case by (simp add: senders_in_def)
qed

lemma p4_reachable:
  assumes "distinct xs" "senders_in ops xs"
  shows "solvent (run (init R) ops) xs"
  using assms p4_init p4_run by blast

end
