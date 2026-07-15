export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  api: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      allocate_customer_payment: {
        Args: {
          p_allocations: Json
          p_correlation_id?: string
          p_credit_remainder: boolean
          p_customer_payment_id: string
          p_idempotency_key: string
          p_organization_id: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      apply_customer_credit: {
        Args: {
          p_amount_minor: number
          p_correlation_id?: string
          p_customer_credit_id: string
          p_idempotency_key: string
          p_order_id: string
          p_organization_id: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      approve_courier_settlement: {
        Args: {
          p_correlation_id?: string
          p_courier_settlement_id: string
          p_idempotency_key: string
          p_organization_id: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      approve_customer_refund: {
        Args: {
          p_correlation_id?: string
          p_idempotency_key: string
          p_organization_id: string
          p_refund_id: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      approve_expense: {
        Args: {
          p_correlation_id?: string
          p_expense_id: string
          p_idempotency_key: string
          p_organization_id: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      approve_partner_withdrawal: {
        Args: {
          p_correlation_id?: string
          p_idempotency_key: string
          p_organization_id: string
          p_partner_withdrawal_id: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      approve_payroll_period: {
        Args: {
          p_correlation_id?: string
          p_idempotency_key: string
          p_organization_id: string
          p_payroll_period_id: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      approve_profit_distribution: {
        Args: {
          p_approval_request_id: string
          p_correlation_id?: string
          p_idempotency_key: string
          p_organization_id: string
          p_profit_distribution_id: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      approve_supplier_invoice: {
        Args: {
          p_correlation_id?: string
          p_idempotency_key: string
          p_organization_id: string
          p_request_fingerprint: string
          p_supplier_invoice_id: string
        }
        Returns: Json
      }
      attest_monthly_close_item: {
        Args: {
          p_actual_minor: number
          p_approval_request_id: string
          p_correlation_id?: string
          p_evidence: Json
          p_expected_minor: number
          p_idempotency_key: string
          p_item_key: string
          p_monthly_closing_id: string
          p_notes: string
          p_organization_id: string
          p_request_fingerprint: string
          p_status: string
        }
        Returns: Json
      }
      calculate_payroll_period: {
        Args: {
          p_correlation_id?: string
          p_idempotency_key: string
          p_organization_id: string
          p_period_start: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      calculate_profit_distribution: {
        Args: {
          p_correlation_id?: string
          p_distribution_amount_minor: number
          p_distribution_no: string
          p_idempotency_key: string
          p_monthly_closing_id: string
          p_organization_id: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      cancel_monthly_close: {
        Args: {
          p_correlation_id?: string
          p_idempotency_key: string
          p_monthly_closing_id: string
          p_organization_id: string
          p_reason: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      cancel_order: {
        Args: {
          p_correlation_id?: string
          p_expected_version: number
          p_idempotency_key: string
          p_order_id: string
          p_organization_id: string
          p_reason: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      close_accounting_period: {
        Args: {
          p_approval_request_id: string
          p_correlation_id?: string
          p_idempotency_key: string
          p_monthly_closing_id: string
          p_organization_id: string
          p_reconciliation_snapshot: Json
          p_request_fingerprint: string
          p_settings_snapshot: Json
        }
        Returns: Json
      }
      close_print_batch: {
        Args: {
          p_correlation_id?: string
          p_idempotency_key: string
          p_organization_id: string
          p_print_batch_id: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      compute_request_fingerprint: {
        Args: {
          p_command_type: string
          p_fingerprint_version?: number
          p_payload: Json
        }
        Returns: string
      }
      confirm_customer_payment: {
        Args: {
          p_correlation_id?: string
          p_customer_payment_id: string
          p_idempotency_key: string
          p_organization_id: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      confirm_order: {
        Args: {
          p_correlation_id?: string
          p_expected_version: number
          p_idempotency_key: string
          p_order_id: string
          p_organization_id: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      create_print_batch: {
        Args: {
          p_batch_number: string
          p_business_date: string
          p_correlation_id?: string
          p_idempotency_key: string
          p_items: Json
          p_organization_id: string
          p_request_fingerprint: string
          p_supplier_id: string
        }
        Returns: Json
      }
      create_shipment: {
        Args: {
          p_correlation_id?: string
          p_courier_id: string
          p_customer_shipping_charge_minor: number
          p_dispatch_evidence_attachment_id: string
          p_expected_order_version: number
          p_idempotency_key: string
          p_items: Json
          p_order_id: string
          p_organization_id: string
          p_request_fingerprint: string
          p_shipment_kind: Database["public"]["Enums"]["shipment_kind"]
          p_shipping_rate_rule_id: string
          p_tracking_number: string
        }
        Returns: Json
      }
      create_supplier_invoice: {
        Args: {
          p_correlation_id?: string
          p_credit_minor: number
          p_due_date: string
          p_idempotency_key: string
          p_invoice_date: string
          p_invoice_number: string
          p_items: Json
          p_organization_id: string
          p_print_batch_id: string
          p_request_fingerprint: string
          p_supplier_id: string
          p_tax_minor: number
        }
        Returns: Json
      }
      decide_approval: {
        Args: {
          p_action: Database["public"]["Enums"]["approval_action_type"]
          p_approval_request_id: string
          p_approver_partner_id?: string
          p_comment?: string
          p_correlation_id?: string
          p_organization_id: string
        }
        Returns: Database["public"]["Enums"]["approval_status"]
      }
      execute_customer_refund: {
        Args: {
          p_correlation_id?: string
          p_evidence_attachment_id: string
          p_external_transaction_reference: string
          p_idempotency_key: string
          p_organization_id: string
          p_refund_id: string
          p_request_fingerprint: string
          p_source_wallet_id: string
        }
        Returns: Json
      }
      execute_partner_withdrawal: {
        Args: {
          p_correlation_id?: string
          p_idempotency_key: string
          p_organization_id: string
          p_partner_withdrawal_id: string
          p_provider_reference: string
          p_request_fingerprint: string
          p_wallet_id: string
        }
        Returns: Json
      }
      finalize_courier_settlement: {
        Args: {
          p_correlation_id?: string
          p_courier_settlement_id: string
          p_idempotency_key: string
          p_organization_id: string
          p_request_fingerprint: string
          p_wallet_id: string
        }
        Returns: Json
      }
      finalize_wallet_reconciliation: {
        Args: {
          p_correlation_id?: string
          p_idempotency_key: string
          p_organization_id: string
          p_request_fingerprint: string
          p_wallet_reconciliation_id: string
        }
        Returns: Json
      }
      grant_order_discount: {
        Args: {
          p_amount_minor: number
          p_approval_request_id: string
          p_correlation_id?: string
          p_expected_version: number
          p_idempotency_key: string
          p_includes_shipping: boolean
          p_order_id: string
          p_organization_id: string
          p_reason: string
          p_request_fingerprint: string
          p_source: string
        }
        Returns: Json
      }
      list_journal_entries: {
        Args: {
          p_cursor_accounting_date?: string
          p_cursor_entry_number?: number
          p_organization_id: string
          p_page_size?: number
          p_period_end?: string
          p_period_start?: string
          p_source_type?: string
          p_status?: Database["public"]["Enums"]["journal_status"]
        }
        Returns: {
          accounting_date: string
          accounting_period_id: string
          affected_closed_period_id: string
          approval_request_id: string
          corrects_entry_id: string
          correlation_id: string
          currency_code: string
          description: string
          entry_number: number
          is_adjustment: boolean
          journal_entry_id: string
          organization_id: string
          period_status: Database["public"]["Enums"]["accounting_period_status"]
          posted_at: string
          posted_by: string
          posting_date: string
          posting_purpose: string
          reversal_of: string
          reversal_reason: string
          reversed_by_entry_id: string
          source_id: string
          source_type: string
          status: Database["public"]["Enums"]["journal_status"]
          total_credit_minor: number
          total_debit_minor: number
        }[]
      }
      list_journal_lines: {
        Args: {
          p_after_line_number?: number
          p_journal_entry_id: string
          p_organization_id: string
          p_page_size?: number
        }
        Returns: {
          account_code: string
          account_id: string
          account_name: string
          account_type: string
          credit_minor: number
          customer_id: string
          debit_minor: number
          description: string
          employee_id: string
          journal_entry_id: string
          journal_line_id: string
          line_number: number
          order_id: string
          organization_id: string
          partner_id: string
          print_batch_id: string
          shipment_id: string
          subledger_id: string
          subledger_type: string
          supplier_id: string
          wallet_id: string
        }[]
      }
      list_monthly_close_checklist: {
        Args: {
          p_monthly_closing_id: string
          p_organization_id: string
          p_status?: string
        }
        Returns: {
          actual_minor: number
          checked_at: string
          checked_by: string
          checklist_item_id: string
          difference_minor: number
          evidence_metadata: Json
          expected_minor: number
          is_blocking: boolean
          item_key: string
          monthly_closing_id: string
          notes: string
          organization_id: string
          status: string
          updated_at: string
        }[]
      }
      list_monthly_closes: {
        Args: {
          p_cursor_period_id?: string
          p_cursor_period_start?: string
          p_organization_id: string
          p_page_size?: number
          p_status?: string
        }
        Returns: {
          accounting_period_id: string
          approval_request_id: string
          approval_status: Database["public"]["Enums"]["approval_status"]
          checklist_version: number
          closed_at: string
          closed_by: string
          closing_status: string
          correlation_id: string
          cumulative_profit_loss_minor: number
          distributable_profit_minor: number
          generated_at: string
          monthly_closing_id: string
          organization_id: string
          period_end: string
          period_expense_minor: number
          period_profit_loss_minor: number
          period_revenue_minor: number
          period_start: string
          period_status: Database["public"]["Enums"]["accounting_period_status"]
          period_version: number
          prior_distributions_minor: number
          protected_reserve_minor: number
          reopen_reason: string
          reopened_at: string
          reopened_by: string
          requested_at: string
          requested_by: string
          trial_balance_credit_minor: number
          trial_balance_debit_minor: number
          validated_at: string
          validated_by: string
          validation_summary: Json
        }[]
      }
      mark_order_delivered: {
        Args: {
          p_correlation_id?: string
          p_delivered_at: string
          p_delivery_evidence_attachment_id: string
          p_expected_shipment_version: number
          p_idempotency_key: string
          p_organization_id: string
          p_reported_collected_cod_minor: number
          p_request_fingerprint: string
          p_shipment_id: string
        }
        Returns: Json
      }
      pay_expense: {
        Args: {
          p_correlation_id?: string
          p_evidence_attachment_id: string
          p_expense_id: string
          p_idempotency_key: string
          p_organization_id: string
          p_provider_reference: string
          p_request_fingerprint: string
          p_wallet_id: string
        }
        Returns: Json
      }
      pay_payroll_entry: {
        Args: {
          p_correlation_id?: string
          p_evidence_attachment_id: string
          p_idempotency_key: string
          p_organization_id: string
          p_payroll_entry_id: string
          p_provider_reference: string
          p_request_fingerprint: string
          p_wallet_id: string
        }
        Returns: Json
      }
      pay_supplier_invoice: {
        Args: {
          p_amount_minor: number
          p_correlation_id?: string
          p_evidence_attachment_id: string
          p_idempotency_key: string
          p_organization_id: string
          p_provider_reference: string
          p_request_fingerprint: string
          p_supplier_invoice_id: string
          p_wallet_id: string
        }
        Returns: Json
      }
      post_journal_entry: {
        Args: {
          p_accounting_date?: string
          p_affected_closed_period_id?: string
          p_approval_request_id?: string
          p_corrects_entry_id?: string
          p_correlation_id?: string
          p_description: string
          p_idempotency_key: string
          p_lines: Json
          p_organization_id: string
          p_posting_purpose: string
          p_request_fingerprint: string
          p_source_id: string
          p_source_type: string
        }
        Returns: Json
      }
      post_profit_distribution: {
        Args: {
          p_correlation_id?: string
          p_idempotency_key: string
          p_organization_id: string
          p_profit_distribution_id: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      prepare_courier_settlement: {
        Args: {
          p_actual_settlement_date: string
          p_actual_transfer_minor: number
          p_adjustments_minor: number
          p_approved_deductions_minor: number
          p_correlation_id?: string
          p_courier_id: string
          p_difference_classification: string
          p_difference_explanation: string
          p_evidence_attachment_id: string
          p_expected_settlement_date: string
          p_idempotency_key: string
          p_is_off_cycle: boolean
          p_off_cycle_reason: string
          p_organization_id: string
          p_period_end: string
          p_period_start: string
          p_prior_carry_forward_minor: number
          p_request_fingerprint: string
          p_settlement_number: string
        }
        Returns: Json
      }
      prepare_wallet_reconciliation: {
        Args: {
          p_actual_closing_balance_minor: number
          p_correlation_id?: string
          p_difference_explanation: string
          p_evidence_attachment_id: string
          p_idempotency_key: string
          p_organization_id: string
          p_period_ended_at: string
          p_period_started_at: string
          p_request_fingerprint: string
          p_wallet_id: string
        }
        Returns: Json
      }
      read_control_account_reconciliation: {
        Args: { p_as_of_date: string; p_organization_id: string }
        Returns: {
          account_code: string
          account_id: string
          account_name: string
          account_role: string
          as_of_date: string
          currency_code: string
          difference_minor: number
          dimensioned_balance_minor: number
          generated_at: string
          last_posted_at: string
          ledger_balance_minor: number
          organization_id: string
          reconciliation_domain: string
          reconciliation_status: string
        }[]
      }
      read_current_access_context: {
        Args: never
        Returns: {
          currency_code: string
          display_name: string
          generated_at: string
          organization_code: string
          organization_id: string
          organization_name: string
          permission_keys: string[]
          profile_status: Database["public"]["Enums"]["user_status"]
          role_keys: string[]
          timezone_name: string
          user_id: string
        }[]
      }
      read_dashboard_summary: {
        Args: {
          p_organization_id: string
          p_period_end: string
          p_period_start: string
        }
        Returns: {
          contra_revenue_minor: number
          currency_code: string
          expense_minor: number
          generated_at: string
          gross_revenue_minor: number
          last_posted_at: string
          last_reconciled_at: string
          negative_inventory_count: number
          net_revenue_minor: number
          open_approval_count: number
          organization_id: string
          pending_withdrawals_minor: number
          period_end: string
          period_start: string
          profit_loss_minor: number
          protected_liabilities_minor: number
          protected_reserve_minor: number
          safe_cash_minor: number
          unposted_event_count: number
          unreconciled_wallet_count: number
          wallet_book_balance_minor: number
        }[]
      }
      read_liquidity_summary: {
        Args: { p_as_of_date: string; p_organization_id: string }
        Returns: {
          as_of_date: string
          book_balance_minor: number
          currency_code: string
          difference_minor: number
          finalized_at: string
          generated_at: string
          is_reconciled: boolean
          last_posted_at: string
          organization_id: string
          physical_balance_minor: number
          provider: string
          reconciled_through_at: string
          reconciliation_id: string
          reconciliation_status: string
          wallet_code: string
          wallet_id: string
          wallet_name: string
        }[]
      }
      read_profit_and_loss: {
        Args: {
          p_organization_id: string
          p_period_end: string
          p_period_start: string
        }
        Returns: {
          contra_revenue_minor: number
          currency_code: string
          expense_minor: number
          generated_at: string
          gross_revenue_minor: number
          last_posted_at: string
          month_end: string
          month_start: string
          net_revenue_minor: number
          organization_id: string
          period_status: string
          profit_loss_minor: number
        }[]
      }
      read_trial_balance: {
        Args: {
          p_organization_id: string
          p_period_end: string
          p_period_start: string
        }
        Returns: {
          account_code: string
          account_id: string
          account_name: string
          account_type: string
          closing_credit_minor: number
          closing_debit_minor: number
          currency_code: string
          generated_at: string
          normal_balance: string
          opening_credit_minor: number
          opening_debit_minor: number
          organization_id: string
          period_credit_minor: number
          period_debit_minor: number
        }[]
      }
      receive_print_batch: {
        Args: {
          p_correlation_id?: string
          p_idempotency_key: string
          p_items: Json
          p_organization_id: string
          p_print_batch_id: string
          p_receipt_number: string
          p_received_at: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      record_customer_payment: {
        Args: {
          p_amount_minor: number
          p_correlation_id?: string
          p_customer_id: string
          p_evidence_attachment_id: string
          p_external_transaction_reference: string
          p_idempotency_key: string
          p_organization_id: string
          p_paid_at: string
          p_payment_method: string
          p_primary_order_id: string
          p_provider_name_snapshot: string
          p_request_fingerprint: string
          p_wallet_id: string
        }
        Returns: Json
      }
      record_expense: {
        Args: {
          p_business_date: string
          p_correlation_id?: string
          p_description: string
          p_due_date: string
          p_evidence_attachment_id: string
          p_expense_category_id: string
          p_expense_number: string
          p_idempotency_key: string
          p_organization_id: string
          p_payable_name_snapshot: string
          p_request_fingerprint: string
          p_subtotal_minor: number
          p_tax_minor: number
        }
        Returns: Json
      }
      record_order_return: {
        Args: {
          p_correlation_id?: string
          p_evidence_attachment_id: string
          p_expected_shipment_version: number
          p_idempotency_key: string
          p_items: Json
          p_organization_id: string
          p_reason: string
          p_request_fingerprint: string
          p_return_number: string
          p_shipment_id: string
        }
        Returns: Json
      }
      record_partner_capital: {
        Args: {
          p_amount_minor: number
          p_correlation_id?: string
          p_evidence_attachment_id: string
          p_idempotency_key: string
          p_organization_id: string
          p_partner_id: string
          p_reason: string
          p_request_fingerprint: string
          p_wallet_id: string
        }
        Returns: Json
      }
      record_partner_loan: {
        Args: {
          p_correlation_id?: string
          p_due_date: string
          p_idempotency_key: string
          p_loan_number: string
          p_organization_id: string
          p_partner_id: string
          p_principal_minor: number
          p_request_fingerprint: string
          p_terms_snapshot: Json
          p_wallet_id: string
        }
        Returns: Json
      }
      recover_monthly_close: {
        Args: {
          p_correlation_id?: string
          p_idempotency_key: string
          p_monthly_closing_id: string
          p_organization_id: string
          p_reason: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      reopen_accounting_period: {
        Args: {
          p_approval_request_id: string
          p_correlation_id?: string
          p_idempotency_key: string
          p_monthly_closing_id: string
          p_organization_id: string
          p_reason: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      request_accounting_period_reopen: {
        Args: {
          p_monthly_closing_id: string
          p_organization_id: string
          p_reason: string
        }
        Returns: Json
      }
      request_customer_refund: {
        Args: {
          p_correlation_id?: string
          p_customer_credit_id: string
          p_customer_id: string
          p_customer_payment_id: string
          p_destination_method: string
          p_destination_reference_snapshot: string
          p_idempotency_key: string
          p_order_id: string
          p_organization_id: string
          p_reason: string
          p_request_fingerprint: string
          p_requested_amount_minor: number
        }
        Returns: Json
      }
      request_journal_reversal: {
        Args: {
          p_correlation_id?: string
          p_idempotency_key: string
          p_organization_id: string
          p_original_entry_id: string
          p_reason: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      request_partner_withdrawal: {
        Args: {
          p_correlation_id?: string
          p_evidence_attachment_id: string
          p_idempotency_key: string
          p_organization_id: string
          p_partner_id: string
          p_reason: string
          p_request_fingerprint: string
          p_requested_amount_minor: number
          p_withdrawal_number: string
          p_withdrawal_type: Database["public"]["Enums"]["partner_withdrawal_type"]
        }
        Returns: Json
      }
      request_wallet_transfer: {
        Args: {
          p_amount_minor: number
          p_correlation_id?: string
          p_destination_wallet_id: string
          p_evidence_attachment_id: string
          p_fee_minor: number
          p_fee_reference: string
          p_idempotency_key: string
          p_organization_id: string
          p_reason: string
          p_request_fingerprint: string
          p_source_wallet_id: string
          p_transfer_reference: string
        }
        Returns: Json
      }
      reverse_customer_payment: {
        Args: {
          p_approval_request_id: string
          p_correlation_id?: string
          p_customer_payment_id: string
          p_idempotency_key: string
          p_organization_id: string
          p_reason: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      reverse_customer_refund: {
        Args: {
          p_approval_request_id: string
          p_correlation_id?: string
          p_idempotency_key: string
          p_organization_id: string
          p_reason: string
          p_refund_id: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      reverse_journal_entry: {
        Args: {
          p_approval_request_id?: string
          p_correlation_id?: string
          p_idempotency_key: string
          p_organization_id: string
          p_original_entry_id: string
          p_reason: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      search_audit_events: {
        Args: {
          p_action?: string
          p_correlation_id?: string
          p_cursor_event_id?: string
          p_cursor_occurred_at?: string
          p_event_category?: string
          p_occurred_from?: string
          p_occurred_to?: string
          p_organization_id: string
          p_page_size?: number
          p_result?: string
          p_subject_id?: string
          p_subject_type?: string
        }
        Returns: {
          action: string
          actor_type: string
          actor_user_id: string
          audit_event_id: string
          command_execution_id: string
          correlation_id: string
          event_category: string
          has_metadata: boolean
          has_state_change: boolean
          occurred_at: string
          organization_id: string
          reason: string
          result: string
          subject_id: string
          subject_type: string
        }[]
      }
      start_monthly_close: {
        Args: {
          p_approval_request_id?: string
          p_correlation_id?: string
          p_idempotency_key: string
          p_organization_id: string
          p_period_start: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
      submit_approval_request: {
        Args: {
          p_entity_id: string
          p_entity_type: string
          p_expires_at?: string
          p_organization_id: string
          p_payload_snapshot: Json
          p_reason: string
          p_request_type: string
          p_requested_amount_minor?: number
          p_requester_partner_id?: string
          p_required_permission: string
          p_subject_fingerprint: string
        }
        Returns: string
      }
      transfer_between_wallets: {
        Args: {
          p_correlation_id?: string
          p_idempotency_key: string
          p_organization_id: string
          p_request_fingerprint: string
          p_wallet_transfer_id: string
        }
        Returns: Json
      }
      validate_monthly_close: {
        Args: {
          p_correlation_id?: string
          p_idempotency_key: string
          p_monthly_closing_id: string
          p_organization_id: string
          p_request_fingerprint: string
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      approval_actions: {
        Row: {
          acted_at: string
          acted_by: string
          action_type: Database["public"]["Enums"]["approval_action_type"]
          approval_request_id: string
          approver_partner_id: string | null
          comment: string | null
          correlation_id: string
          id: string
          organization_id: string
          previous_status: Database["public"]["Enums"]["approval_status"]
          resulting_status: Database["public"]["Enums"]["approval_status"]
          subject_fingerprint: string
        }
        Insert: {
          acted_at?: string
          acted_by: string
          action_type: Database["public"]["Enums"]["approval_action_type"]
          approval_request_id: string
          approver_partner_id?: string | null
          comment?: string | null
          correlation_id: string
          id?: string
          organization_id: string
          previous_status: Database["public"]["Enums"]["approval_status"]
          resulting_status: Database["public"]["Enums"]["approval_status"]
          subject_fingerprint: string
        }
        Update: {
          acted_at?: string
          acted_by?: string
          action_type?: Database["public"]["Enums"]["approval_action_type"]
          approval_request_id?: string
          approver_partner_id?: string | null
          comment?: string | null
          correlation_id?: string
          id?: string
          organization_id?: string
          previous_status?: Database["public"]["Enums"]["approval_status"]
          resulting_status?: Database["public"]["Enums"]["approval_status"]
          subject_fingerprint?: string
        }
        Relationships: [
          {
            foreignKeyName: "approval_actions_actor_org_fk"
            columns: ["organization_id", "acted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "approval_actions_approver_partner_org_fk"
            columns: ["organization_id", "approver_partner_id"]
            isOneToOne: false
            referencedRelation: "partner_account_summary"
            referencedColumns: ["organization_id", "partner_id"]
          },
          {
            foreignKeyName: "approval_actions_approver_partner_org_fk"
            columns: ["organization_id", "approver_partner_id"]
            isOneToOne: false
            referencedRelation: "partners"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "approval_actions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "approval_actions_request_org_fk"
            columns: ["organization_id", "approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      approval_requests: {
        Row: {
          approved_max_amount_minor: number | null
          approved_min_amount_minor: number | null
          consumed_at: string | null
          consumed_by_command_execution_id: string | null
          created_at: string
          entity_id: string
          entity_type: string
          expires_at: string | null
          fingerprint_version: number
          id: string
          organization_id: string
          payload_snapshot: Json
          reason: string
          request_type: string
          requested_amount_minor: number | null
          requested_at: string
          requested_by: string
          requester_partner_id: string | null
          required_approval_count: number
          required_permission_id: string
          requires_separation_of_duties: boolean
          resolution_reason: string | null
          resolved_at: string | null
          resolved_by: string | null
          status: Database["public"]["Enums"]["approval_status"]
          subject_fingerprint: string
          submitted_at: string | null
          updated_at: string
        }
        Insert: {
          approved_max_amount_minor?: number | null
          approved_min_amount_minor?: number | null
          consumed_at?: string | null
          consumed_by_command_execution_id?: string | null
          created_at?: string
          entity_id: string
          entity_type: string
          expires_at?: string | null
          fingerprint_version?: number
          id?: string
          organization_id: string
          payload_snapshot?: Json
          reason: string
          request_type: string
          requested_amount_minor?: number | null
          requested_at?: string
          requested_by: string
          requester_partner_id?: string | null
          required_approval_count?: number
          required_permission_id: string
          requires_separation_of_duties?: boolean
          resolution_reason?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          status?: Database["public"]["Enums"]["approval_status"]
          subject_fingerprint: string
          submitted_at?: string | null
          updated_at?: string
        }
        Update: {
          approved_max_amount_minor?: number | null
          approved_min_amount_minor?: number | null
          consumed_at?: string | null
          consumed_by_command_execution_id?: string | null
          created_at?: string
          entity_id?: string
          entity_type?: string
          expires_at?: string | null
          fingerprint_version?: number
          id?: string
          organization_id?: string
          payload_snapshot?: Json
          reason?: string
          request_type?: string
          requested_amount_minor?: number | null
          requested_at?: string
          requested_by?: string
          requester_partner_id?: string | null
          required_approval_count?: number
          required_permission_id?: string
          requires_separation_of_duties?: boolean
          resolution_reason?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          status?: Database["public"]["Enums"]["approval_status"]
          subject_fingerprint?: string
          submitted_at?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "approval_requests_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "approval_requests_requester_org_fk"
            columns: ["organization_id", "requested_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "approval_requests_requester_partner_org_fk"
            columns: ["organization_id", "requester_partner_id"]
            isOneToOne: false
            referencedRelation: "partner_account_summary"
            referencedColumns: ["organization_id", "partner_id"]
          },
          {
            foreignKeyName: "approval_requests_requester_partner_org_fk"
            columns: ["organization_id", "requester_partner_id"]
            isOneToOne: false
            referencedRelation: "partners"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "approval_requests_resolver_org_fk"
            columns: ["organization_id", "resolved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      attachments: {
        Row: {
          bucket_id: string
          checksum_sha256: string | null
          classification: string
          created_at: string
          deleted_at: string | null
          entity_id: string
          entity_type: string
          id: string
          media_type: string | null
          object_name: string
          organization_id: string
          size_bytes: number | null
          uploaded_by: string
        }
        Insert: {
          bucket_id: string
          checksum_sha256?: string | null
          classification?: string
          created_at?: string
          deleted_at?: string | null
          entity_id: string
          entity_type: string
          id?: string
          media_type?: string | null
          object_name: string
          organization_id: string
          size_bytes?: number | null
          uploaded_by: string
        }
        Update: {
          bucket_id?: string
          checksum_sha256?: string | null
          classification?: string
          created_at?: string
          deleted_at?: string | null
          entity_id?: string
          entity_type?: string
          id?: string
          media_type?: string | null
          object_name?: string
          organization_id?: string
          size_bytes?: number | null
          uploaded_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "attachments_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attachments_uploader_org_fk"
            columns: ["organization_id", "uploaded_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      bonus_adjustments: {
        Row: {
          amount_minor: number
          applied_payroll_entry_id: string | null
          applies_to_period_start: string
          approval_request_id: string
          created_at: string
          created_by: string
          employee_id: string
          id: string
          organization_id: string
          reason: string
          source_event_id: string
          source_event_type: string
          source_performance_review_id: string
          updated_at: string
          updated_by: string
        }
        Insert: {
          amount_minor: number
          applied_payroll_entry_id?: string | null
          applies_to_period_start: string
          approval_request_id: string
          created_at?: string
          created_by: string
          employee_id: string
          id?: string
          organization_id: string
          reason: string
          source_event_id: string
          source_event_type: string
          source_performance_review_id: string
          updated_at?: string
          updated_by: string
        }
        Update: {
          amount_minor?: number
          applied_payroll_entry_id?: string | null
          applies_to_period_start?: string
          approval_request_id?: string
          created_at?: string
          created_by?: string
          employee_id?: string
          id?: string
          organization_id?: string
          reason?: string
          source_event_id?: string
          source_event_type?: string
          source_performance_review_id?: string
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "bonus_adjustments_approval_fk"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bonus_adjustments_approval_org_fk"
            columns: ["organization_id", "approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "bonus_adjustments_employee_fk"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bonus_adjustments_employee_org_fk"
            columns: ["organization_id", "employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "bonus_adjustments_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bonus_adjustments_payroll_entry_fk"
            columns: ["applied_payroll_entry_id"]
            isOneToOne: false
            referencedRelation: "payroll_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bonus_adjustments_payroll_entry_org_fk"
            columns: ["organization_id", "applied_payroll_entry_id"]
            isOneToOne: false
            referencedRelation: "payroll_entries"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "bonus_adjustments_review_fk"
            columns: ["source_performance_review_id"]
            isOneToOne: false
            referencedRelation: "employee_performance_reviews"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bonus_adjustments_review_org_fk"
            columns: ["organization_id", "source_performance_review_id"]
            isOneToOne: false
            referencedRelation: "employee_performance_reviews"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      bonus_metrics: {
        Row: {
          bonus_scheme_id: string
          created_at: string
          created_by: string
          display_order: number
          id: string
          metric_code: string
          name: string
          organization_id: string
          source_definition: Json
          updated_at: string
          updated_by: string
          weight_bps: number
        }
        Insert: {
          bonus_scheme_id: string
          created_at?: string
          created_by: string
          display_order?: number
          id?: string
          metric_code: string
          name: string
          organization_id: string
          source_definition: Json
          updated_at?: string
          updated_by: string
          weight_bps: number
        }
        Update: {
          bonus_scheme_id?: string
          created_at?: string
          created_by?: string
          display_order?: number
          id?: string
          metric_code?: string
          name?: string
          organization_id?: string
          source_definition?: Json
          updated_at?: string
          updated_by?: string
          weight_bps?: number
        }
        Relationships: [
          {
            foreignKeyName: "bonus_metrics_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bonus_metrics_scheme_fk"
            columns: ["bonus_scheme_id"]
            isOneToOne: false
            referencedRelation: "bonus_schemes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bonus_metrics_scheme_org_fk"
            columns: ["organization_id", "bonus_scheme_id"]
            isOneToOne: false
            referencedRelation: "bonus_schemes"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      bonus_schemes: {
        Row: {
          approval_request_id: string | null
          created_at: string
          created_by: string | null
          effective_from: string
          effective_to: string | null
          employee_kind: Database["public"]["Enums"]["employee_kind"]
          id: string
          is_active: boolean
          maximum_bonus_minor: number
          minimum_bonus_minor: number
          minimum_score_bps: number
          name: string
          organization_id: string
          scheme_code: string
          source_cutoff_policy: Json
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          approval_request_id?: string | null
          created_at?: string
          created_by?: string | null
          effective_from: string
          effective_to?: string | null
          employee_kind: Database["public"]["Enums"]["employee_kind"]
          id?: string
          is_active?: boolean
          maximum_bonus_minor: number
          minimum_bonus_minor: number
          minimum_score_bps?: number
          name: string
          organization_id: string
          scheme_code: string
          source_cutoff_policy: Json
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          approval_request_id?: string | null
          created_at?: string
          created_by?: string | null
          effective_from?: string
          effective_to?: string | null
          employee_kind?: Database["public"]["Enums"]["employee_kind"]
          id?: string
          is_active?: boolean
          maximum_bonus_minor?: number
          minimum_bonus_minor?: number
          minimum_score_bps?: number
          name?: string
          organization_id?: string
          scheme_code?: string
          source_cutoff_policy?: Json
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "bonus_schemes_approval_fk"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bonus_schemes_approval_org_fk"
            columns: ["organization_id", "approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "bonus_schemes_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      bonus_slabs: {
        Row: {
          bonus_minor: number
          bonus_scheme_id: string
          created_at: string
          created_by: string
          id: string
          maximum_score_bps: number
          minimum_score_bps: number
          organization_id: string
          updated_at: string
          updated_by: string
        }
        Insert: {
          bonus_minor: number
          bonus_scheme_id: string
          created_at?: string
          created_by: string
          id?: string
          maximum_score_bps: number
          minimum_score_bps: number
          organization_id: string
          updated_at?: string
          updated_by: string
        }
        Update: {
          bonus_minor?: number
          bonus_scheme_id?: string
          created_at?: string
          created_by?: string
          id?: string
          maximum_score_bps?: number
          minimum_score_bps?: number
          organization_id?: string
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "bonus_slabs_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bonus_slabs_scheme_fk"
            columns: ["bonus_scheme_id"]
            isOneToOne: false
            referencedRelation: "bonus_schemes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bonus_slabs_scheme_org_fk"
            columns: ["organization_id", "bonus_scheme_id"]
            isOneToOne: false
            referencedRelation: "bonus_schemes"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      courier_settlement_items: {
        Row: {
          amount_minor: number
          courier_reported_amount_minor: number | null
          courier_settlement_id: string
          created_at: string
          created_by: string
          description: string
          id: string
          is_active: boolean
          line_type: Database["public"]["Enums"]["courier_settlement_line_type"]
          organization_id: string
          return_id: string | null
          shipment_id: string | null
          shipment_item_id: string | null
          source_event_key: string
          updated_at: string
          updated_by: string
        }
        Insert: {
          amount_minor: number
          courier_reported_amount_minor?: number | null
          courier_settlement_id: string
          created_at?: string
          created_by: string
          description: string
          id?: string
          is_active?: boolean
          line_type: Database["public"]["Enums"]["courier_settlement_line_type"]
          organization_id: string
          return_id?: string | null
          shipment_id?: string | null
          shipment_item_id?: string | null
          source_event_key: string
          updated_at?: string
          updated_by: string
        }
        Update: {
          amount_minor?: number
          courier_reported_amount_minor?: number | null
          courier_settlement_id?: string
          created_at?: string
          created_by?: string
          description?: string
          id?: string
          is_active?: boolean
          line_type?: Database["public"]["Enums"]["courier_settlement_line_type"]
          organization_id?: string
          return_id?: string | null
          shipment_id?: string | null
          shipment_item_id?: string | null
          source_event_key?: string
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "courier_settlement_items_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "courier_settlement_items_return_fk"
            columns: ["return_id"]
            isOneToOne: false
            referencedRelation: "returns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "courier_settlement_items_return_org_fk"
            columns: ["organization_id", "return_id"]
            isOneToOne: false
            referencedRelation: "returns"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "courier_settlement_items_settlement_fk"
            columns: ["courier_settlement_id"]
            isOneToOne: false
            referencedRelation: "courier_settlement_summary"
            referencedColumns: ["settlement_id"]
          },
          {
            foreignKeyName: "courier_settlement_items_settlement_fk"
            columns: ["courier_settlement_id"]
            isOneToOne: false
            referencedRelation: "courier_settlements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "courier_settlement_items_settlement_org_fk"
            columns: ["organization_id", "courier_settlement_id"]
            isOneToOne: false
            referencedRelation: "courier_settlement_summary"
            referencedColumns: ["organization_id", "settlement_id"]
          },
          {
            foreignKeyName: "courier_settlement_items_settlement_org_fk"
            columns: ["organization_id", "courier_settlement_id"]
            isOneToOne: false
            referencedRelation: "courier_settlements"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "courier_settlement_items_shipment_fk"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "courier_settlement_items_shipment_item_fk"
            columns: ["shipment_item_id"]
            isOneToOne: false
            referencedRelation: "shipment_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "courier_settlement_items_shipment_item_org_fk"
            columns: ["organization_id", "shipment_item_id"]
            isOneToOne: false
            referencedRelation: "shipment_items"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "courier_settlement_items_shipment_org_fk"
            columns: ["organization_id", "shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      courier_settlements: {
        Row: {
          actual_settlement_date: string | null
          actual_transfer_minor: number | null
          adjustments_minor: number
          approval_request_id: string | null
          approved_deductions_minor: number
          contractual_cod_minor: number
          courier_id: string
          created_at: string
          created_by: string
          delivery_fees_minor: number
          difference_classification: string | null
          difference_explanation: string | null
          difference_minor: number | null
          evidence_attachment_id: string | null
          expected_net_settlement_minor: number
          expected_settlement_date: string
          id: string
          is_off_cycle: boolean
          journal_entry_id: string | null
          off_cycle_reason: string | null
          organization_id: string
          period_end: string
          period_start: string
          posted_at: string | null
          prior_carry_forward_minor: number
          return_fees_minor: number
          settlement_no: string
          status: Database["public"]["Enums"]["settlement_status"]
          updated_at: string
          updated_by: string
          version: number
          wallet_id: string | null
        }
        Insert: {
          actual_settlement_date?: string | null
          actual_transfer_minor?: number | null
          adjustments_minor?: number
          approval_request_id?: string | null
          approved_deductions_minor?: number
          contractual_cod_minor?: number
          courier_id: string
          created_at?: string
          created_by: string
          delivery_fees_minor?: number
          difference_classification?: string | null
          difference_explanation?: string | null
          difference_minor?: number | null
          evidence_attachment_id?: string | null
          expected_net_settlement_minor?: number
          expected_settlement_date: string
          id?: string
          is_off_cycle?: boolean
          journal_entry_id?: string | null
          off_cycle_reason?: string | null
          organization_id: string
          period_end: string
          period_start: string
          posted_at?: string | null
          prior_carry_forward_minor?: number
          return_fees_minor?: number
          settlement_no: string
          status?: Database["public"]["Enums"]["settlement_status"]
          updated_at?: string
          updated_by: string
          version?: number
          wallet_id?: string | null
        }
        Update: {
          actual_settlement_date?: string | null
          actual_transfer_minor?: number | null
          adjustments_minor?: number
          approval_request_id?: string | null
          approved_deductions_minor?: number
          contractual_cod_minor?: number
          courier_id?: string
          created_at?: string
          created_by?: string
          delivery_fees_minor?: number
          difference_classification?: string | null
          difference_explanation?: string | null
          difference_minor?: number | null
          evidence_attachment_id?: string | null
          expected_net_settlement_minor?: number
          expected_settlement_date?: string
          id?: string
          is_off_cycle?: boolean
          journal_entry_id?: string | null
          off_cycle_reason?: string | null
          organization_id?: string
          period_end?: string
          period_start?: string
          posted_at?: string | null
          prior_carry_forward_minor?: number
          return_fees_minor?: number
          settlement_no?: string
          status?: Database["public"]["Enums"]["settlement_status"]
          updated_at?: string
          updated_by?: string
          version?: number
          wallet_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "courier_settlements_approval_fk"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "courier_settlements_approval_org_fk"
            columns: ["organization_id", "approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "courier_settlements_courier_fk"
            columns: ["courier_id"]
            isOneToOne: false
            referencedRelation: "couriers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "courier_settlements_courier_org_fk"
            columns: ["organization_id", "courier_id"]
            isOneToOne: false
            referencedRelation: "couriers"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "courier_settlements_evidence_attachment_id_org_fk"
            columns: ["organization_id", "evidence_attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "courier_settlements_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "courier_settlements_wallet_fk"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["wallet_id"]
          },
          {
            foreignKeyName: "courier_settlements_wallet_fk"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "courier_settlements_wallet_org_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["organization_id", "wallet_id"]
          },
          {
            foreignKeyName: "courier_settlements_wallet_org_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      couriers: {
        Row: {
          archived_at: string | null
          contact_name: string | null
          courier_code: string
          created_at: string
          created_by: string | null
          display_name: string
          id: string
          is_active: boolean
          legal_name: string | null
          notes: string | null
          organization_id: string
          phone_normalized: string | null
          phone_original: string | null
          settlement_timezone_name: string
          settlement_weekdays: number[]
          updated_at: string
        }
        Insert: {
          archived_at?: string | null
          contact_name?: string | null
          courier_code: string
          created_at?: string
          created_by?: string | null
          display_name: string
          id?: string
          is_active?: boolean
          legal_name?: string | null
          notes?: string | null
          organization_id: string
          phone_normalized?: string | null
          phone_original?: string | null
          settlement_timezone_name?: string
          settlement_weekdays?: number[]
          updated_at?: string
        }
        Update: {
          archived_at?: string | null
          contact_name?: string | null
          courier_code?: string
          created_at?: string
          created_by?: string | null
          display_name?: string
          id?: string
          is_active?: boolean
          legal_name?: string | null
          notes?: string | null
          organization_id?: string
          phone_normalized?: string | null
          phone_original?: string | null
          settlement_timezone_name?: string
          settlement_weekdays?: number[]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "couriers_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      customer_addresses: {
        Row: {
          address_line_1: string
          address_line_2: string | null
          archive_reason: string | null
          archived_at: string | null
          archived_by: string | null
          area: string | null
          city: string
          created_at: string
          created_by: string | null
          customer_id: string
          delivery_notes: string | null
          governorate: string
          id: string
          is_active: boolean
          is_default: boolean
          label: string | null
          landmark: string | null
          organization_id: string
          postal_code: string | null
          recipient_name: string
          recipient_phone_normalized: string | null
          recipient_phone_original: string | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          address_line_1: string
          address_line_2?: string | null
          archive_reason?: string | null
          archived_at?: string | null
          archived_by?: string | null
          area?: string | null
          city: string
          created_at?: string
          created_by?: string | null
          customer_id: string
          delivery_notes?: string | null
          governorate: string
          id?: string
          is_active?: boolean
          is_default?: boolean
          label?: string | null
          landmark?: string | null
          organization_id: string
          postal_code?: string | null
          recipient_name: string
          recipient_phone_normalized?: string | null
          recipient_phone_original?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          address_line_1?: string
          address_line_2?: string | null
          archive_reason?: string | null
          archived_at?: string | null
          archived_by?: string | null
          area?: string | null
          city?: string
          created_at?: string
          created_by?: string | null
          customer_id?: string
          delivery_notes?: string | null
          governorate?: string
          id?: string
          is_active?: boolean
          is_default?: boolean
          label?: string | null
          landmark?: string | null
          organization_id?: string
          postal_code?: string | null
          recipient_name?: string
          recipient_phone_normalized?: string | null
          recipient_phone_original?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "customer_addresses_customer_org_fk"
            columns: ["organization_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "customer_addresses_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      customer_credit_movements: {
        Row: {
          amount_minor: number
          correlation_id: string
          created_at: string
          created_by: string
          customer_credit_id: string
          customer_id: string
          id: string
          journal_entry_id: string | null
          movement_type: string
          occurred_at: string
          order_id: string | null
          organization_id: string
          payment_allocation_id: string | null
          reason: string
          refund_id: string | null
          updated_at: string
        }
        Insert: {
          amount_minor: number
          correlation_id: string
          created_at?: string
          created_by: string
          customer_credit_id: string
          customer_id: string
          id?: string
          journal_entry_id?: string | null
          movement_type: string
          occurred_at?: string
          order_id?: string | null
          organization_id: string
          payment_allocation_id?: string | null
          reason: string
          refund_id?: string | null
          updated_at?: string
        }
        Update: {
          amount_minor?: number
          correlation_id?: string
          created_at?: string
          created_by?: string
          customer_credit_id?: string
          customer_id?: string
          id?: string
          journal_entry_id?: string | null
          movement_type?: string
          occurred_at?: string
          order_id?: string | null
          organization_id?: string
          payment_allocation_id?: string | null
          reason?: string
          refund_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_credit_movements_allocation_fk"
            columns: ["organization_id", "payment_allocation_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "payment_allocations"
            referencedColumns: ["organization_id", "id", "customer_id"]
          },
          {
            foreignKeyName: "customer_credit_movements_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_credit_movements_credit_fk"
            columns: ["organization_id", "customer_credit_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "customer_credits"
            referencedColumns: ["organization_id", "id", "customer_id"]
          },
          {
            foreignKeyName: "customer_credit_movements_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_credit_movements_order_fk"
            columns: ["organization_id", "order_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "order_financial_summary"
            referencedColumns: ["organization_id", "order_id", "customer_id"]
          },
          {
            foreignKeyName: "customer_credit_movements_order_fk"
            columns: ["organization_id", "order_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["organization_id", "id", "customer_id"]
          },
          {
            foreignKeyName: "customer_credit_movements_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_credit_movements_refund_fk"
            columns: ["organization_id", "refund_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "refunds"
            referencedColumns: ["organization_id", "id", "customer_id"]
          },
        ]
      }
      customer_credits: {
        Row: {
          closed_at: string | null
          created_at: string
          created_by: string
          currency: string
          customer_id: string
          expires_at: string | null
          id: string
          organization_id: string
          original_amount_minor: number
          reason: string
          remaining_amount_minor: number
          source_payment_id: string | null
          status: string
          updated_at: string
        }
        Insert: {
          closed_at?: string | null
          created_at?: string
          created_by: string
          currency?: string
          customer_id: string
          expires_at?: string | null
          id?: string
          organization_id: string
          original_amount_minor: number
          reason: string
          remaining_amount_minor: number
          source_payment_id?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          closed_at?: string | null
          created_at?: string
          created_by?: string
          currency?: string
          customer_id?: string
          expires_at?: string | null
          id?: string
          organization_id?: string
          original_amount_minor?: number
          reason?: string
          remaining_amount_minor?: number
          source_payment_id?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_credits_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_credits_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_credits_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_credits_source_payment_fk"
            columns: ["organization_id", "source_payment_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "customer_payments"
            referencedColumns: ["organization_id", "id", "customer_id"]
          },
        ]
      }
      customer_payments: {
        Row: {
          amount_minor: number
          confirmed_at: string | null
          correlation_id: string
          created_at: string
          currency: string
          customer_id: string
          evidence_attachment_id: string | null
          external_transaction_reference: string | null
          id: string
          idempotency_key: string
          organization_id: string
          paid_at: string
          payment_method: string
          primary_order_id: string | null
          provider_name_snapshot: string | null
          recorded_by: string
          rejected_at: string | null
          request_fingerprint: string
          reversal_event_id: string | null
          reversal_payment_id: string | null
          reversed_at: string | null
          review_reason: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: Database["public"]["Enums"]["payment_review_status"]
          updated_at: string
          wallet_id: string
        }
        Insert: {
          amount_minor: number
          confirmed_at?: string | null
          correlation_id: string
          created_at?: string
          currency?: string
          customer_id: string
          evidence_attachment_id?: string | null
          external_transaction_reference?: string | null
          id?: string
          idempotency_key: string
          organization_id: string
          paid_at: string
          payment_method: string
          primary_order_id?: string | null
          provider_name_snapshot?: string | null
          recorded_by: string
          rejected_at?: string | null
          request_fingerprint: string
          reversal_event_id?: string | null
          reversal_payment_id?: string | null
          reversed_at?: string | null
          review_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["payment_review_status"]
          updated_at?: string
          wallet_id: string
        }
        Update: {
          amount_minor?: number
          confirmed_at?: string | null
          correlation_id?: string
          created_at?: string
          currency?: string
          customer_id?: string
          evidence_attachment_id?: string | null
          external_transaction_reference?: string | null
          id?: string
          idempotency_key?: string
          organization_id?: string
          paid_at?: string
          payment_method?: string
          primary_order_id?: string | null
          provider_name_snapshot?: string | null
          recorded_by?: string
          rejected_at?: string | null
          request_fingerprint?: string
          reversal_event_id?: string | null
          reversal_payment_id?: string | null
          reversed_at?: string | null
          review_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["payment_review_status"]
          updated_at?: string
          wallet_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "customer_payments_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_payments_evidence_attachment_id_org_fk"
            columns: ["organization_id", "evidence_attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "customer_payments_order_fk"
            columns: ["organization_id", "primary_order_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "order_financial_summary"
            referencedColumns: ["organization_id", "order_id", "customer_id"]
          },
          {
            foreignKeyName: "customer_payments_order_fk"
            columns: ["organization_id", "primary_order_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["organization_id", "id", "customer_id"]
          },
          {
            foreignKeyName: "customer_payments_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_payments_recorded_by_fkey"
            columns: ["recorded_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_payments_reversal_event_fk"
            columns: ["organization_id", "reversal_event_id"]
            isOneToOne: false
            referencedRelation: "payment_reversal_events"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "customer_payments_reversal_fk"
            columns: ["organization_id", "reversal_payment_id"]
            isOneToOne: false
            referencedRelation: "customer_payments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "customer_payments_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_payments_wallet_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["organization_id", "wallet_id"]
          },
          {
            foreignKeyName: "customer_payments_wallet_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      customers: {
        Row: {
          alternate_phone_normalized: string | null
          alternate_phone_original: string | null
          archive_reason: string | null
          archived_at: string | null
          archived_by: string | null
          assigned_to_user_id: string | null
          created_at: string
          created_by: string | null
          customer_number: string
          full_name: string
          id: string
          is_active: boolean
          notes: string | null
          organization_id: string
          phone_normalized: string | null
          phone_original: string | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          alternate_phone_normalized?: string | null
          alternate_phone_original?: string | null
          archive_reason?: string | null
          archived_at?: string | null
          archived_by?: string | null
          assigned_to_user_id?: string | null
          created_at?: string
          created_by?: string | null
          customer_number: string
          full_name: string
          id?: string
          is_active?: boolean
          notes?: string | null
          organization_id: string
          phone_normalized?: string | null
          phone_original?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          alternate_phone_normalized?: string | null
          alternate_phone_original?: string | null
          archive_reason?: string | null
          archived_at?: string | null
          archived_by?: string | null
          assigned_to_user_id?: string | null
          created_at?: string
          created_by?: string | null
          customer_number?: string
          full_name?: string
          id?: string
          is_active?: boolean
          notes?: string | null
          organization_id?: string
          phone_normalized?: string | null
          phone_original?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "customers_assignee_org_fk"
            columns: ["organization_id", "assigned_to_user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "customers_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      employee_advances: {
        Row: {
          amount_minor: number
          approval_request_id: string | null
          created_at: string
          created_by: string
          employee_id: string
          id: string
          journal_entry_id: string | null
          organization_id: string
          paid_date: string | null
          reason: string
          recovered_minor: number
          request_date: string
          status: Database["public"]["Enums"]["employee_advance_status"]
          updated_at: string
          updated_by: string
          version: number
          wallet_id: string | null
        }
        Insert: {
          amount_minor: number
          approval_request_id?: string | null
          created_at?: string
          created_by: string
          employee_id: string
          id?: string
          journal_entry_id?: string | null
          organization_id: string
          paid_date?: string | null
          reason: string
          recovered_minor?: number
          request_date: string
          status?: Database["public"]["Enums"]["employee_advance_status"]
          updated_at?: string
          updated_by: string
          version?: number
          wallet_id?: string | null
        }
        Update: {
          amount_minor?: number
          approval_request_id?: string | null
          created_at?: string
          created_by?: string
          employee_id?: string
          id?: string
          journal_entry_id?: string | null
          organization_id?: string
          paid_date?: string | null
          reason?: string
          recovered_minor?: number
          request_date?: string
          status?: Database["public"]["Enums"]["employee_advance_status"]
          updated_at?: string
          updated_by?: string
          version?: number
          wallet_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "employee_advances_approval_fk"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "employee_advances_approval_org_fk"
            columns: ["organization_id", "approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "employee_advances_employee_fk"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "employee_advances_employee_org_fk"
            columns: ["organization_id", "employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "employee_advances_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "employee_advances_wallet_fk"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["wallet_id"]
          },
          {
            foreignKeyName: "employee_advances_wallet_fk"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "employee_advances_wallet_org_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["organization_id", "wallet_id"]
          },
          {
            foreignKeyName: "employee_advances_wallet_org_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      employee_compensation_periods: {
        Row: {
          approval_request_id: string
          base_salary_minor: number
          created_at: string
          created_by: string
          currency_code: string
          effective_from: string
          effective_to: string | null
          employee_id: string
          final_pay_policy_snapshot: Json
          id: string
          organization_id: string
          proration_policy_snapshot: Json
          updated_at: string
          updated_by: string
        }
        Insert: {
          approval_request_id: string
          base_salary_minor: number
          created_at?: string
          created_by: string
          currency_code?: string
          effective_from: string
          effective_to?: string | null
          employee_id: string
          final_pay_policy_snapshot?: Json
          id?: string
          organization_id: string
          proration_policy_snapshot?: Json
          updated_at?: string
          updated_by: string
        }
        Update: {
          approval_request_id?: string
          base_salary_minor?: number
          created_at?: string
          created_by?: string
          currency_code?: string
          effective_from?: string
          effective_to?: string | null
          employee_id?: string
          final_pay_policy_snapshot?: Json
          id?: string
          organization_id?: string
          proration_policy_snapshot?: Json
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "employee_compensation_periods_approval_fk"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "employee_compensation_periods_approval_org_fk"
            columns: ["organization_id", "approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "employee_compensation_periods_employee_fk"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "employee_compensation_periods_employee_org_fk"
            columns: ["organization_id", "employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "employee_compensation_periods_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      employee_performance_reviews: {
        Row: {
          approved_at: string | null
          approved_by: string | null
          attribution_snapshot: Json
          bonus_scheme_id: string
          calculated_bonus_minor: number
          calculated_score_bps: number
          created_at: string
          created_by: string
          employee_id: string
          final_bonus_minor: number
          id: string
          metric_period_end: string
          metric_period_start: string
          organization_id: string
          override_approved_at: string | null
          override_approved_by: string | null
          override_bonus_minor: number | null
          override_reason: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          source_cutoff_at: string
          source_rows_snapshot: Json
          status: Database["public"]["Enums"]["bonus_review_status"]
          updated_at: string
          updated_by: string
          version: number
        }
        Insert: {
          approved_at?: string | null
          approved_by?: string | null
          attribution_snapshot: Json
          bonus_scheme_id: string
          calculated_bonus_minor?: number
          calculated_score_bps?: number
          created_at?: string
          created_by: string
          employee_id: string
          final_bonus_minor?: number
          id?: string
          metric_period_end: string
          metric_period_start: string
          organization_id: string
          override_approved_at?: string | null
          override_approved_by?: string | null
          override_bonus_minor?: number | null
          override_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          source_cutoff_at: string
          source_rows_snapshot: Json
          status?: Database["public"]["Enums"]["bonus_review_status"]
          updated_at?: string
          updated_by: string
          version?: number
        }
        Update: {
          approved_at?: string | null
          approved_by?: string | null
          attribution_snapshot?: Json
          bonus_scheme_id?: string
          calculated_bonus_minor?: number
          calculated_score_bps?: number
          created_at?: string
          created_by?: string
          employee_id?: string
          final_bonus_minor?: number
          id?: string
          metric_period_end?: string
          metric_period_start?: string
          organization_id?: string
          override_approved_at?: string | null
          override_approved_by?: string | null
          override_bonus_minor?: number | null
          override_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          source_cutoff_at?: string
          source_rows_snapshot?: Json
          status?: Database["public"]["Enums"]["bonus_review_status"]
          updated_at?: string
          updated_by?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "employee_performance_reviews_employee_fk"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "employee_performance_reviews_employee_org_fk"
            columns: ["organization_id", "employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "employee_performance_reviews_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "employee_performance_reviews_scheme_fk"
            columns: ["bonus_scheme_id"]
            isOneToOne: false
            referencedRelation: "bonus_schemes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "employee_performance_reviews_scheme_org_fk"
            columns: ["organization_id", "bonus_scheme_id"]
            isOneToOne: false
            referencedRelation: "bonus_schemes"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      employee_performance_scores: {
        Row: {
          bonus_metric_id: string
          created_at: string
          created_by: string
          employee_performance_review_id: string
          evidence_snapshot: Json
          id: string
          organization_id: string
          raw_value: number | null
          score_bps: number
          updated_at: string
          updated_by: string
          weight_bps_snapshot: number
          weighted_score_bps: number
        }
        Insert: {
          bonus_metric_id: string
          created_at?: string
          created_by: string
          employee_performance_review_id: string
          evidence_snapshot?: Json
          id?: string
          organization_id: string
          raw_value?: number | null
          score_bps: number
          updated_at?: string
          updated_by: string
          weight_bps_snapshot: number
          weighted_score_bps: number
        }
        Update: {
          bonus_metric_id?: string
          created_at?: string
          created_by?: string
          employee_performance_review_id?: string
          evidence_snapshot?: Json
          id?: string
          organization_id?: string
          raw_value?: number | null
          score_bps?: number
          updated_at?: string
          updated_by?: string
          weight_bps_snapshot?: number
          weighted_score_bps?: number
        }
        Relationships: [
          {
            foreignKeyName: "employee_performance_scores_metric_fk"
            columns: ["bonus_metric_id"]
            isOneToOne: false
            referencedRelation: "bonus_metrics"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "employee_performance_scores_metric_org_fk"
            columns: ["organization_id", "bonus_metric_id"]
            isOneToOne: false
            referencedRelation: "bonus_metrics"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "employee_performance_scores_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "employee_performance_scores_review_fk"
            columns: ["employee_performance_review_id"]
            isOneToOne: false
            referencedRelation: "employee_performance_reviews"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "employee_performance_scores_review_org_fk"
            columns: ["organization_id", "employee_performance_review_id"]
            isOneToOne: false
            referencedRelation: "employee_performance_reviews"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      employees: {
        Row: {
          created_at: string
          created_by: string
          employee_kind: Database["public"]["Enums"]["employee_kind"]
          employee_no: string
          full_name: string
          hire_date: string
          id: string
          organization_id: string
          payment_recipient_name: string | null
          payment_recipient_reference: string | null
          payroll_enabled: boolean
          profile_id: string | null
          status: Database["public"]["Enums"]["employee_status"]
          termination_date: string | null
          updated_at: string
          updated_by: string
          version: number
        }
        Insert: {
          created_at?: string
          created_by: string
          employee_kind: Database["public"]["Enums"]["employee_kind"]
          employee_no: string
          full_name: string
          hire_date: string
          id?: string
          organization_id: string
          payment_recipient_name?: string | null
          payment_recipient_reference?: string | null
          payroll_enabled?: boolean
          profile_id?: string | null
          status?: Database["public"]["Enums"]["employee_status"]
          termination_date?: string | null
          updated_at?: string
          updated_by: string
          version?: number
        }
        Update: {
          created_at?: string
          created_by?: string
          employee_kind?: Database["public"]["Enums"]["employee_kind"]
          employee_no?: string
          full_name?: string
          hire_date?: string
          id?: string
          organization_id?: string
          payment_recipient_name?: string | null
          payment_recipient_reference?: string | null
          payroll_enabled?: boolean
          profile_id?: string | null
          status?: Database["public"]["Enums"]["employee_status"]
          termination_date?: string | null
          updated_at?: string
          updated_by?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "employees_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "employees_profile_fk"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "employees_profile_org_fk"
            columns: ["organization_id", "profile_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      expense_categories: {
        Row: {
          code: string
          created_at: string
          created_by: string | null
          id: string
          is_active: boolean
          name: string
          organization_id: string
          permits_order_allocation: boolean
          requires_approval: boolean
          requires_evidence: boolean
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          name: string
          organization_id: string
          permits_order_allocation?: boolean
          requires_approval?: boolean
          requires_evidence?: boolean
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          name?: string
          organization_id?: string
          permits_order_allocation?: boolean
          requires_approval?: boolean
          requires_evidence?: boolean
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "expense_categories_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      expense_payments: {
        Row: {
          amount_minor: number
          created_at: string
          created_by: string
          evidence_attachment_id: string | null
          expense_id: string
          id: string
          journal_entry_id: string | null
          organization_id: string
          payment_date: string
          provider_reference: string | null
          reverses_expense_payment_id: string | null
          updated_at: string
          updated_by: string
          wallet_id: string
        }
        Insert: {
          amount_minor: number
          created_at?: string
          created_by: string
          evidence_attachment_id?: string | null
          expense_id: string
          id?: string
          journal_entry_id?: string | null
          organization_id: string
          payment_date: string
          provider_reference?: string | null
          reverses_expense_payment_id?: string | null
          updated_at?: string
          updated_by: string
          wallet_id: string
        }
        Update: {
          amount_minor?: number
          created_at?: string
          created_by?: string
          evidence_attachment_id?: string | null
          expense_id?: string
          id?: string
          journal_entry_id?: string | null
          organization_id?: string
          payment_date?: string
          provider_reference?: string | null
          reverses_expense_payment_id?: string | null
          updated_at?: string
          updated_by?: string
          wallet_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "expense_payments_evidence_attachment_id_org_fk"
            columns: ["organization_id", "evidence_attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "expense_payments_expense_fk"
            columns: ["expense_id"]
            isOneToOne: false
            referencedRelation: "expenses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expense_payments_expense_org_fk"
            columns: ["organization_id", "expense_id"]
            isOneToOne: false
            referencedRelation: "expenses"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "expense_payments_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expense_payments_reversal_fk"
            columns: ["reverses_expense_payment_id"]
            isOneToOne: false
            referencedRelation: "expense_payments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expense_payments_reversal_org_fk"
            columns: ["organization_id", "reverses_expense_payment_id"]
            isOneToOne: false
            referencedRelation: "expense_payments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "expense_payments_wallet_fk"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["wallet_id"]
          },
          {
            foreignKeyName: "expense_payments_wallet_fk"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expense_payments_wallet_org_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["organization_id", "wallet_id"]
          },
          {
            foreignKeyName: "expense_payments_wallet_org_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      expenses: {
        Row: {
          approval_request_id: string | null
          business_date: string
          cancellation_reason: string | null
          created_at: string
          created_by: string
          description: string
          due_date: string | null
          evidence_attachment_id: string | null
          evidence_required: boolean
          expense_category_id: string
          expense_no: string
          id: string
          journal_entry_id: string | null
          order_id: string | null
          order_item_id: string | null
          organization_id: string
          paid_minor: number
          payable_counterparty_id: string | null
          payable_counterparty_type: string | null
          payable_name_snapshot: string | null
          status: Database["public"]["Enums"]["expense_status"]
          subtotal_minor: number
          tax_minor: number
          total_minor: number
          updated_at: string
          updated_by: string
          version: number
        }
        Insert: {
          approval_request_id?: string | null
          business_date: string
          cancellation_reason?: string | null
          created_at?: string
          created_by: string
          description: string
          due_date?: string | null
          evidence_attachment_id?: string | null
          evidence_required?: boolean
          expense_category_id: string
          expense_no: string
          id?: string
          journal_entry_id?: string | null
          order_id?: string | null
          order_item_id?: string | null
          organization_id: string
          paid_minor?: number
          payable_counterparty_id?: string | null
          payable_counterparty_type?: string | null
          payable_name_snapshot?: string | null
          status?: Database["public"]["Enums"]["expense_status"]
          subtotal_minor: number
          tax_minor?: number
          total_minor: number
          updated_at?: string
          updated_by: string
          version?: number
        }
        Update: {
          approval_request_id?: string | null
          business_date?: string
          cancellation_reason?: string | null
          created_at?: string
          created_by?: string
          description?: string
          due_date?: string | null
          evidence_attachment_id?: string | null
          evidence_required?: boolean
          expense_category_id?: string
          expense_no?: string
          id?: string
          journal_entry_id?: string | null
          order_id?: string | null
          order_item_id?: string | null
          organization_id?: string
          paid_minor?: number
          payable_counterparty_id?: string | null
          payable_counterparty_type?: string | null
          payable_name_snapshot?: string | null
          status?: Database["public"]["Enums"]["expense_status"]
          subtotal_minor?: number
          tax_minor?: number
          total_minor?: number
          updated_at?: string
          updated_by?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "expenses_approval_fk"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expenses_approval_org_fk"
            columns: ["organization_id", "approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "expenses_category_fk"
            columns: ["expense_category_id"]
            isOneToOne: false
            referencedRelation: "expense_categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expenses_category_org_fk"
            columns: ["organization_id", "expense_category_id"]
            isOneToOne: false
            referencedRelation: "expense_categories"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "expenses_evidence_attachment_id_org_fk"
            columns: ["organization_id", "evidence_attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "expenses_order_fk"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "order_financial_summary"
            referencedColumns: ["order_id"]
          },
          {
            foreignKeyName: "expenses_order_fk"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expenses_order_item_fk"
            columns: ["order_item_id"]
            isOneToOne: false
            referencedRelation: "order_item_margin_summary"
            referencedColumns: ["order_item_id"]
          },
          {
            foreignKeyName: "expenses_order_item_fk"
            columns: ["order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expenses_order_item_org_fk"
            columns: ["organization_id", "order_item_id"]
            isOneToOne: false
            referencedRelation: "order_item_margin_summary"
            referencedColumns: ["organization_id", "order_item_id"]
          },
          {
            foreignKeyName: "expenses_order_item_org_fk"
            columns: ["organization_id", "order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "expenses_order_org_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "order_financial_summary"
            referencedColumns: ["organization_id", "order_id"]
          },
          {
            foreignKeyName: "expenses_order_org_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "expenses_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      governorate_shipping_fees: {
        Row: {
          created_at: string
          governorate: string
          id: string
          organization_id: string
          shipping_fee: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          governorate: string
          id?: string
          organization_id?: string
          shipping_fee?: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          governorate?: string
          id?: string
          organization_id?: string
          shipping_fee?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "governorate_shipping_fees_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      grni_accruals: {
        Row: {
          accepted_quantity: number
          accounting_date: string
          accrued_amount_minor: number
          created_at: string
          created_by: string
          entry_kind: string
          id: string
          journal_entry_id: string | null
          organization_id: string
          print_batch_item_id: string
          print_batch_qc_event_id: string
          reverses_grni_accrual_id: string | null
          unit_cost_minor: number
          updated_at: string
          updated_by: string
        }
        Insert: {
          accepted_quantity: number
          accounting_date: string
          accrued_amount_minor: number
          created_at?: string
          created_by: string
          entry_kind?: string
          id?: string
          journal_entry_id?: string | null
          organization_id: string
          print_batch_item_id: string
          print_batch_qc_event_id: string
          reverses_grni_accrual_id?: string | null
          unit_cost_minor: number
          updated_at?: string
          updated_by: string
        }
        Update: {
          accepted_quantity?: number
          accounting_date?: string
          accrued_amount_minor?: number
          created_at?: string
          created_by?: string
          entry_kind?: string
          id?: string
          journal_entry_id?: string | null
          organization_id?: string
          print_batch_item_id?: string
          print_batch_qc_event_id?: string
          reverses_grni_accrual_id?: string | null
          unit_cost_minor?: number
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "grni_accruals_batch_item_fk"
            columns: ["print_batch_item_id"]
            isOneToOne: false
            referencedRelation: "print_batch_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "grni_accruals_batch_item_org_fk"
            columns: ["organization_id", "print_batch_item_id"]
            isOneToOne: false
            referencedRelation: "print_batch_items"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "grni_accruals_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "grni_accruals_qc_event_fk"
            columns: ["print_batch_qc_event_id"]
            isOneToOne: false
            referencedRelation: "print_batch_qc_events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "grni_accruals_qc_event_org_fk"
            columns: ["organization_id", "print_batch_qc_event_id"]
            isOneToOne: false
            referencedRelation: "print_batch_qc_events"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "grni_accruals_reversal_fk"
            columns: ["reverses_grni_accrual_id"]
            isOneToOne: false
            referencedRelation: "grni_accruals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "grni_accruals_reversal_org_fk"
            columns: ["organization_id", "reverses_grni_accrual_id"]
            isOneToOne: false
            referencedRelation: "grni_accruals"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      inventory_locations: {
        Row: {
          code: string
          created_at: string
          created_by: string | null
          id: string
          is_active: boolean
          location_kind: string
          name: string
          organization_id: string
          permits_negative_on_hand: boolean
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          location_kind: string
          name: string
          organization_id: string
          permits_negative_on_hand?: boolean
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          location_kind?: string
          name?: string
          organization_id?: string
          permits_negative_on_hand?: boolean
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "inventory_locations_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      inventory_movements: {
        Row: {
          accounting_date: string
          approval_request_id: string | null
          correlation_id: string
          created_at: string
          created_by: string
          from_location_id: string | null
          id: string
          inventory_reservation_id: string | null
          journal_entry_id: string | null
          movement_type: Database["public"]["Enums"]["inventory_movement_type"]
          occurred_at: string
          order_item_id: string | null
          organization_id: string
          print_batch_item_id: string | null
          product_variant_id: string
          quantity: number
          reason: string
          responsibility: string | null
          source_id: string
          source_type: string
          to_location_id: string | null
          total_cost_minor: number
          unit_cost_minor: number
          updated_at: string
          updated_by: string
        }
        Insert: {
          accounting_date: string
          approval_request_id?: string | null
          correlation_id: string
          created_at?: string
          created_by: string
          from_location_id?: string | null
          id?: string
          inventory_reservation_id?: string | null
          journal_entry_id?: string | null
          movement_type: Database["public"]["Enums"]["inventory_movement_type"]
          occurred_at: string
          order_item_id?: string | null
          organization_id: string
          print_batch_item_id?: string | null
          product_variant_id: string
          quantity: number
          reason: string
          responsibility?: string | null
          source_id: string
          source_type: string
          to_location_id?: string | null
          total_cost_minor: number
          unit_cost_minor: number
          updated_at?: string
          updated_by: string
        }
        Update: {
          accounting_date?: string
          approval_request_id?: string | null
          correlation_id?: string
          created_at?: string
          created_by?: string
          from_location_id?: string | null
          id?: string
          inventory_reservation_id?: string | null
          journal_entry_id?: string | null
          movement_type?: Database["public"]["Enums"]["inventory_movement_type"]
          occurred_at?: string
          order_item_id?: string | null
          organization_id?: string
          print_batch_item_id?: string | null
          product_variant_id?: string
          quantity?: number
          reason?: string
          responsibility?: string | null
          source_id?: string
          source_type?: string
          to_location_id?: string | null
          total_cost_minor?: number
          unit_cost_minor?: number
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "inventory_movements_approval_fk"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_movements_approval_org_fk"
            columns: ["organization_id", "approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "inventory_movements_batch_item_fk"
            columns: ["print_batch_item_id"]
            isOneToOne: false
            referencedRelation: "print_batch_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_movements_batch_item_org_fk"
            columns: ["organization_id", "print_batch_item_id"]
            isOneToOne: false
            referencedRelation: "print_batch_items"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "inventory_movements_from_location_fk"
            columns: ["from_location_id"]
            isOneToOne: false
            referencedRelation: "inventory_locations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_movements_from_location_org_fk"
            columns: ["organization_id", "from_location_id"]
            isOneToOne: false
            referencedRelation: "inventory_locations"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "inventory_movements_order_item_fk"
            columns: ["order_item_id"]
            isOneToOne: false
            referencedRelation: "order_item_margin_summary"
            referencedColumns: ["order_item_id"]
          },
          {
            foreignKeyName: "inventory_movements_order_item_fk"
            columns: ["order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_movements_order_item_org_fk"
            columns: ["organization_id", "order_item_id"]
            isOneToOne: false
            referencedRelation: "order_item_margin_summary"
            referencedColumns: ["organization_id", "order_item_id"]
          },
          {
            foreignKeyName: "inventory_movements_order_item_org_fk"
            columns: ["organization_id", "order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "inventory_movements_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_movements_reservation_fk"
            columns: ["inventory_reservation_id"]
            isOneToOne: false
            referencedRelation: "inventory_reservations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_movements_reservation_org_fk"
            columns: ["organization_id", "inventory_reservation_id"]
            isOneToOne: false
            referencedRelation: "inventory_reservations"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "inventory_movements_to_location_fk"
            columns: ["to_location_id"]
            isOneToOne: false
            referencedRelation: "inventory_locations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_movements_to_location_org_fk"
            columns: ["organization_id", "to_location_id"]
            isOneToOne: false
            referencedRelation: "inventory_locations"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "inventory_movements_variant_fk"
            columns: ["product_variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_movements_variant_org_fk"
            columns: ["organization_id", "product_variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      inventory_reservations: {
        Row: {
          consumed_quantity: number
          created_at: string
          created_by: string
          expires_at: string | null
          id: string
          location_id: string
          order_item_id: string
          organization_id: string
          product_variant_id: string
          quantity: number
          released_quantity: number
          reserved_at: string
          status: string
          unit_cost_minor: number
          updated_at: string
          updated_by: string
          version: number
        }
        Insert: {
          consumed_quantity?: number
          created_at?: string
          created_by: string
          expires_at?: string | null
          id?: string
          location_id: string
          order_item_id: string
          organization_id: string
          product_variant_id: string
          quantity: number
          released_quantity?: number
          reserved_at?: string
          status?: string
          unit_cost_minor: number
          updated_at?: string
          updated_by: string
          version?: number
        }
        Update: {
          consumed_quantity?: number
          created_at?: string
          created_by?: string
          expires_at?: string | null
          id?: string
          location_id?: string
          order_item_id?: string
          organization_id?: string
          product_variant_id?: string
          quantity?: number
          released_quantity?: number
          reserved_at?: string
          status?: string
          unit_cost_minor?: number
          updated_at?: string
          updated_by?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "inventory_reservations_location_fk"
            columns: ["location_id"]
            isOneToOne: false
            referencedRelation: "inventory_locations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_reservations_location_org_fk"
            columns: ["organization_id", "location_id"]
            isOneToOne: false
            referencedRelation: "inventory_locations"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "inventory_reservations_order_item_fk"
            columns: ["order_item_id"]
            isOneToOne: false
            referencedRelation: "order_item_margin_summary"
            referencedColumns: ["order_item_id"]
          },
          {
            foreignKeyName: "inventory_reservations_order_item_fk"
            columns: ["order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_reservations_order_item_org_fk"
            columns: ["organization_id", "order_item_id"]
            isOneToOne: false
            referencedRelation: "order_item_margin_summary"
            referencedColumns: ["organization_id", "order_item_id"]
          },
          {
            foreignKeyName: "inventory_reservations_order_item_org_fk"
            columns: ["organization_id", "order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "inventory_reservations_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_reservations_variant_fk"
            columns: ["product_variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_reservations_variant_org_fk"
            columns: ["organization_id", "product_variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      labels: {
        Row: {
          address: string
          cancellation_reason: string | null
          cancelled_at: string | null
          city: string
          cod_amount: number
          contents: string
          created_at: string
          created_by: string
          customer_name: string
          governorate: string
          id: string
          instructions: string | null
          internal_notes: string | null
          is_printed: boolean
          landmark: string | null
          organization_id: string
          payment_method: string
          pieces: number
          primary_phone: string
          printed_at: string | null
          product_name: string | null
          product_type: string
          secondary_phone: string | null
          shipper_id: string
          shipping_fee: number
          status: string
          store_name: string
          tracking_number: string
          updated_at: string
          weight: number
        }
        Insert: {
          address: string
          cancellation_reason?: string | null
          cancelled_at?: string | null
          city: string
          cod_amount?: number
          contents: string
          created_at?: string
          created_by?: string
          customer_name: string
          governorate: string
          id?: string
          instructions?: string | null
          internal_notes?: string | null
          is_printed?: boolean
          landmark?: string | null
          organization_id?: string
          payment_method?: string
          pieces?: number
          primary_phone: string
          printed_at?: string | null
          product_name?: string | null
          product_type?: string
          secondary_phone?: string | null
          shipper_id?: string
          shipping_fee?: number
          status?: string
          store_name?: string
          tracking_number: string
          updated_at?: string
          weight?: number
        }
        Update: {
          address?: string
          cancellation_reason?: string | null
          cancelled_at?: string | null
          city?: string
          cod_amount?: number
          contents?: string
          created_at?: string
          created_by?: string
          customer_name?: string
          governorate?: string
          id?: string
          instructions?: string | null
          internal_notes?: string | null
          is_printed?: boolean
          landmark?: string | null
          organization_id?: string
          payment_method?: string
          pieces?: number
          primary_phone?: string
          printed_at?: string | null
          product_name?: string | null
          product_type?: string
          secondary_phone?: string | null
          shipper_id?: string
          shipping_fee?: number
          status?: string
          store_name?: string
          tracking_number?: string
          updated_at?: string
          weight?: number
        }
        Relationships: [
          {
            foreignKeyName: "labels_created_by_org_fk"
            columns: ["organization_id", "created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "labels_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      order_discount_allocations: {
        Row: {
          allocated_amount_minor: number
          allocation_base_minor: number
          allocation_target: string
          created_at: string
          id: string
          order_discount_id: string
          order_id: string
          order_item_id: string | null
          organization_id: string
          remainder_rank: number
          updated_at: string
        }
        Insert: {
          allocated_amount_minor: number
          allocation_base_minor: number
          allocation_target: string
          created_at?: string
          id?: string
          order_discount_id: string
          order_id: string
          order_item_id?: string | null
          organization_id: string
          remainder_rank: number
          updated_at?: string
        }
        Update: {
          allocated_amount_minor?: number
          allocation_base_minor?: number
          allocation_target?: string
          created_at?: string
          id?: string
          order_discount_id?: string
          order_id?: string
          order_item_id?: string | null
          organization_id?: string
          remainder_rank?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "order_discount_allocations_discount_fk"
            columns: ["organization_id", "order_discount_id", "order_id"]
            isOneToOne: false
            referencedRelation: "order_discounts"
            referencedColumns: ["organization_id", "id", "order_id"]
          },
          {
            foreignKeyName: "order_discount_allocations_item_fk"
            columns: ["organization_id", "order_id", "order_item_id"]
            isOneToOne: false
            referencedRelation: "order_item_margin_summary"
            referencedColumns: ["organization_id", "order_id", "order_item_id"]
          },
          {
            foreignKeyName: "order_discount_allocations_item_fk"
            columns: ["organization_id", "order_id", "order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["organization_id", "order_id", "id"]
          },
          {
            foreignKeyName: "order_discount_allocations_order_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "order_financial_summary"
            referencedColumns: ["organization_id", "order_id"]
          },
          {
            foreignKeyName: "order_discount_allocations_order_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "order_discount_allocations_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      order_discounts: {
        Row: {
          allocation_fingerprint: string
          allocation_method: string
          amount_minor: number
          approval_request_id: string | null
          created_at: string
          discount_bps: number | null
          discount_type: string
          eligible_base_minor: number
          expected_cost_snapshot_minor: number
          expected_margin_after_discount_minor: number
          frozen_at: string
          granted_by: string
          id: string
          includes_shipping: boolean
          order_id: string
          organization_id: string
          reason: string | null
          source: string
          updated_at: string
        }
        Insert: {
          allocation_fingerprint: string
          allocation_method?: string
          amount_minor: number
          approval_request_id?: string | null
          created_at?: string
          discount_bps?: number | null
          discount_type: string
          eligible_base_minor: number
          expected_cost_snapshot_minor: number
          expected_margin_after_discount_minor: number
          frozen_at?: string
          granted_by: string
          id?: string
          includes_shipping?: boolean
          order_id: string
          organization_id: string
          reason?: string | null
          source: string
          updated_at?: string
        }
        Update: {
          allocation_fingerprint?: string
          allocation_method?: string
          amount_minor?: number
          approval_request_id?: string | null
          created_at?: string
          discount_bps?: number | null
          discount_type?: string
          eligible_base_minor?: number
          expected_cost_snapshot_minor?: number
          expected_margin_after_discount_minor?: number
          frozen_at?: string
          granted_by?: string
          id?: string
          includes_shipping?: boolean
          order_id?: string
          organization_id?: string
          reason?: string | null
          source?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "order_discounts_approval_request_id_fkey"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_discounts_granted_by_fkey"
            columns: ["granted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_discounts_order_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "order_financial_summary"
            referencedColumns: ["organization_id", "order_id"]
          },
          {
            foreignKeyName: "order_discounts_order_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "order_discounts_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      order_exceptions: {
        Row: {
          approval_request_id: string | null
          baseline_value: Json
          consumed_at: string | null
          created_at: string
          decided_at: string | null
          decided_by: string | null
          exception_type: string
          expires_at: string | null
          id: string
          order_id: string
          organization_id: string
          reason: string
          requested_at: string
          requested_by: string
          requested_value: Json
          status: string
          subject_fingerprint: string
          updated_at: string
        }
        Insert: {
          approval_request_id?: string | null
          baseline_value?: Json
          consumed_at?: string | null
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          exception_type: string
          expires_at?: string | null
          id?: string
          order_id: string
          organization_id: string
          reason: string
          requested_at?: string
          requested_by: string
          requested_value: Json
          status?: string
          subject_fingerprint: string
          updated_at?: string
        }
        Update: {
          approval_request_id?: string | null
          baseline_value?: Json
          consumed_at?: string | null
          created_at?: string
          decided_at?: string | null
          decided_by?: string | null
          exception_type?: string
          expires_at?: string | null
          id?: string
          order_id?: string
          organization_id?: string
          reason?: string
          requested_at?: string
          requested_by?: string
          requested_value?: Json
          status?: string
          subject_fingerprint?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "order_exceptions_approval_request_id_fkey"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_exceptions_decided_by_fkey"
            columns: ["decided_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_exceptions_order_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "order_financial_summary"
            referencedColumns: ["organization_id", "order_id"]
          },
          {
            foreignKeyName: "order_exceptions_order_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "order_exceptions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_exceptions_requested_by_fkey"
            columns: ["requested_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      order_items: {
        Row: {
          actual_cost_minor: number
          cost_source_snapshot: Json
          costing_status: string
          created_at: string
          currency: string
          custom_design_required: boolean
          fulfillment_status: Database["public"]["Enums"]["fulfillment_status"]
          id: string
          item_name_snapshot: string
          item_type: Database["public"]["Enums"]["item_type"]
          line_discount_minor: number
          line_gross_minor: number
          line_number: number
          line_revenue_minor: number
          order_id: string
          organization_id: string
          original_order_item_id: string | null
          phone_model_id: string | null
          phone_model_snapshot: string | null
          price_source_snapshot: Json
          printing_required: boolean
          product_id: string | null
          product_variant_id: string | null
          quantity: number
          sku_snapshot: string | null
          supply_method: Database["public"]["Enums"]["supply_method"]
          terms_frozen_at: string | null
          unit_expected_cost_minor: number
          unit_sale_price_minor: number
          updated_at: string
          version: number
        }
        Insert: {
          actual_cost_minor?: number
          cost_source_snapshot?: Json
          costing_status?: string
          created_at?: string
          currency?: string
          custom_design_required?: boolean
          fulfillment_status?: Database["public"]["Enums"]["fulfillment_status"]
          id?: string
          item_name_snapshot: string
          item_type: Database["public"]["Enums"]["item_type"]
          line_discount_minor?: number
          line_gross_minor: number
          line_number: number
          line_revenue_minor: number
          order_id: string
          organization_id: string
          original_order_item_id?: string | null
          phone_model_id?: string | null
          phone_model_snapshot?: string | null
          price_source_snapshot?: Json
          printing_required?: boolean
          product_id?: string | null
          product_variant_id?: string | null
          quantity: number
          sku_snapshot?: string | null
          supply_method: Database["public"]["Enums"]["supply_method"]
          terms_frozen_at?: string | null
          unit_expected_cost_minor: number
          unit_sale_price_minor: number
          updated_at?: string
          version?: number
        }
        Update: {
          actual_cost_minor?: number
          cost_source_snapshot?: Json
          costing_status?: string
          created_at?: string
          currency?: string
          custom_design_required?: boolean
          fulfillment_status?: Database["public"]["Enums"]["fulfillment_status"]
          id?: string
          item_name_snapshot?: string
          item_type?: Database["public"]["Enums"]["item_type"]
          line_discount_minor?: number
          line_gross_minor?: number
          line_number?: number
          line_revenue_minor?: number
          order_id?: string
          organization_id?: string
          original_order_item_id?: string | null
          phone_model_id?: string | null
          phone_model_snapshot?: string | null
          price_source_snapshot?: Json
          printing_required?: boolean
          product_id?: string | null
          product_variant_id?: string | null
          quantity?: number
          sku_snapshot?: string | null
          supply_method?: Database["public"]["Enums"]["supply_method"]
          terms_frozen_at?: string | null
          unit_expected_cost_minor?: number
          unit_sale_price_minor?: number
          updated_at?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "order_items_order_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "order_financial_summary"
            referencedColumns: ["organization_id", "order_id"]
          },
          {
            foreignKeyName: "order_items_order_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "order_items_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_original_item_fk"
            columns: ["organization_id", "original_order_item_id"]
            isOneToOne: false
            referencedRelation: "order_item_margin_summary"
            referencedColumns: ["organization_id", "order_item_id"]
          },
          {
            foreignKeyName: "order_items_original_item_fk"
            columns: ["organization_id", "original_order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "order_items_phone_model_id_fkey"
            columns: ["phone_model_id"]
            isOneToOne: false
            referencedRelation: "phone_models"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_product_variant_id_fkey"
            columns: ["product_variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id"]
          },
        ]
      }
      order_problem_costs: {
        Row: {
          amount_minor: number
          approval_request_id: string | null
          approved: boolean
          cost_type: string
          created_at: string
          created_by: string
          currency: string
          evidence_attachment_id: string | null
          id: string
          incurred_at: string
          order_id: string
          order_item_id: string | null
          order_problem_id: string
          organization_id: string
          reason: string
          recoverable: boolean
          responsibility: string | null
          updated_at: string
        }
        Insert: {
          amount_minor: number
          approval_request_id?: string | null
          approved?: boolean
          cost_type: string
          created_at?: string
          created_by: string
          currency?: string
          evidence_attachment_id?: string | null
          id?: string
          incurred_at: string
          order_id: string
          order_item_id?: string | null
          order_problem_id: string
          organization_id: string
          reason: string
          recoverable?: boolean
          responsibility?: string | null
          updated_at?: string
        }
        Update: {
          amount_minor?: number
          approval_request_id?: string | null
          approved?: boolean
          cost_type?: string
          created_at?: string
          created_by?: string
          currency?: string
          evidence_attachment_id?: string | null
          id?: string
          incurred_at?: string
          order_id?: string
          order_item_id?: string | null
          order_problem_id?: string
          organization_id?: string
          reason?: string
          recoverable?: boolean
          responsibility?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "order_problem_costs_approval_request_id_fkey"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_problem_costs_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_problem_costs_evidence_attachment_id_org_fk"
            columns: ["organization_id", "evidence_attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "order_problem_costs_item_fk"
            columns: ["organization_id", "order_id", "order_item_id"]
            isOneToOne: false
            referencedRelation: "order_item_margin_summary"
            referencedColumns: ["organization_id", "order_id", "order_item_id"]
          },
          {
            foreignKeyName: "order_problem_costs_item_fk"
            columns: ["organization_id", "order_id", "order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["organization_id", "order_id", "id"]
          },
          {
            foreignKeyName: "order_problem_costs_order_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "order_financial_summary"
            referencedColumns: ["organization_id", "order_id"]
          },
          {
            foreignKeyName: "order_problem_costs_order_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "order_problem_costs_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_problem_costs_problem_fk"
            columns: ["organization_id", "order_problem_id", "order_id"]
            isOneToOne: false
            referencedRelation: "order_problems"
            referencedColumns: ["organization_id", "id", "order_id"]
          },
        ]
      }
      order_problems: {
        Row: {
          assigned_to: string | null
          created_at: string
          details: string | null
          evidence_attachment_id: string | null
          id: string
          opened_at: string
          order_id: string
          order_item_id: string | null
          organization_id: string
          problem_type: string
          reported_by: string
          resolution: string | null
          resolved_at: string | null
          responsibility: string | null
          severity: string
          status: string
          summary: string
          updated_at: string
        }
        Insert: {
          assigned_to?: string | null
          created_at?: string
          details?: string | null
          evidence_attachment_id?: string | null
          id?: string
          opened_at?: string
          order_id: string
          order_item_id?: string | null
          organization_id: string
          problem_type: string
          reported_by: string
          resolution?: string | null
          resolved_at?: string | null
          responsibility?: string | null
          severity?: string
          status?: string
          summary: string
          updated_at?: string
        }
        Update: {
          assigned_to?: string | null
          created_at?: string
          details?: string | null
          evidence_attachment_id?: string | null
          id?: string
          opened_at?: string
          order_id?: string
          order_item_id?: string | null
          organization_id?: string
          problem_type?: string
          reported_by?: string
          resolution?: string | null
          resolved_at?: string | null
          responsibility?: string | null
          severity?: string
          status?: string
          summary?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "order_problems_assigned_to_fkey"
            columns: ["assigned_to"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_problems_evidence_attachment_id_org_fk"
            columns: ["organization_id", "evidence_attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "order_problems_item_fk"
            columns: ["organization_id", "order_id", "order_item_id"]
            isOneToOne: false
            referencedRelation: "order_item_margin_summary"
            referencedColumns: ["organization_id", "order_id", "order_item_id"]
          },
          {
            foreignKeyName: "order_problems_item_fk"
            columns: ["organization_id", "order_id", "order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["organization_id", "order_id", "id"]
          },
          {
            foreignKeyName: "order_problems_order_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "order_financial_summary"
            referencedColumns: ["organization_id", "order_id"]
          },
          {
            foreignKeyName: "order_problems_order_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "order_problems_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_problems_reported_by_fkey"
            columns: ["reported_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      order_status_history: {
        Row: {
          changed_by: string
          correlation_id: string
          created_at: string
          id: string
          new_status: Database["public"]["Enums"]["order_status"]
          occurred_at: string
          order_id: string
          order_version: number
          organization_id: string
          previous_status: Database["public"]["Enums"]["order_status"] | null
          reason: string | null
          updated_at: string
        }
        Insert: {
          changed_by: string
          correlation_id: string
          created_at?: string
          id?: string
          new_status: Database["public"]["Enums"]["order_status"]
          occurred_at?: string
          order_id: string
          order_version: number
          organization_id: string
          previous_status?: Database["public"]["Enums"]["order_status"] | null
          reason?: string | null
          updated_at?: string
        }
        Update: {
          changed_by?: string
          correlation_id?: string
          created_at?: string
          id?: string
          new_status?: Database["public"]["Enums"]["order_status"]
          occurred_at?: string
          order_id?: string
          order_version?: number
          organization_id?: string
          previous_status?: Database["public"]["Enums"]["order_status"] | null
          reason?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "order_status_history_changed_by_fkey"
            columns: ["changed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_status_history_order_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "order_financial_summary"
            referencedColumns: ["organization_id", "order_id"]
          },
          {
            foreignKeyName: "order_status_history_order_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "order_status_history_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      orders: {
        Row: {
          actual_cost_minor: number
          actual_margin_minor: number
          assigned_moderator_id: string | null
          balance_due_minor: number
          cancellation_reason: string | null
          cancelled_at: string | null
          confirmed_at: string | null
          confirmed_payment_minor: number
          created_at: string
          created_by: string
          currency: string
          customer_address_id: string | null
          customer_id: string
          delivered_at: string | null
          deposit_bps_snapshot: number | null
          discount_total_minor: number
          expected_cost_minor: number
          expected_margin_minor: number
          financially_settled_at: string | null
          id: string
          order_number: string
          order_source: string
          order_total_minor: number
          order_type: string
          organization_id: string
          payment_policy_code_snapshot: string | null
          payment_policy_version_snapshot: string | null
          payment_status: Database["public"]["Enums"]["payment_status"]
          products_subtotal_minor: number
          required_deposit_minor: number
          shipping_address_snapshot: Json | null
          shipping_charge_minor: number
          shipping_phone_snapshot: string | null
          shipping_prepaid_required_snapshot: boolean | null
          shipping_recipient_name_snapshot: string | null
          status: Database["public"]["Enums"]["order_status"]
          terms_frozen_at: string | null
          updated_at: string
          version: number
        }
        Insert: {
          actual_cost_minor?: number
          actual_margin_minor?: number
          assigned_moderator_id?: string | null
          balance_due_minor?: number
          cancellation_reason?: string | null
          cancelled_at?: string | null
          confirmed_at?: string | null
          confirmed_payment_minor?: number
          created_at?: string
          created_by: string
          currency?: string
          customer_address_id?: string | null
          customer_id: string
          delivered_at?: string | null
          deposit_bps_snapshot?: number | null
          discount_total_minor?: number
          expected_cost_minor?: number
          expected_margin_minor?: number
          financially_settled_at?: string | null
          id?: string
          order_number: string
          order_source: string
          order_total_minor?: number
          order_type: string
          organization_id: string
          payment_policy_code_snapshot?: string | null
          payment_policy_version_snapshot?: string | null
          payment_status?: Database["public"]["Enums"]["payment_status"]
          products_subtotal_minor?: number
          required_deposit_minor?: number
          shipping_address_snapshot?: Json | null
          shipping_charge_minor?: number
          shipping_phone_snapshot?: string | null
          shipping_prepaid_required_snapshot?: boolean | null
          shipping_recipient_name_snapshot?: string | null
          status?: Database["public"]["Enums"]["order_status"]
          terms_frozen_at?: string | null
          updated_at?: string
          version?: number
        }
        Update: {
          actual_cost_minor?: number
          actual_margin_minor?: number
          assigned_moderator_id?: string | null
          balance_due_minor?: number
          cancellation_reason?: string | null
          cancelled_at?: string | null
          confirmed_at?: string | null
          confirmed_payment_minor?: number
          created_at?: string
          created_by?: string
          currency?: string
          customer_address_id?: string | null
          customer_id?: string
          delivered_at?: string | null
          deposit_bps_snapshot?: number | null
          discount_total_minor?: number
          expected_cost_minor?: number
          expected_margin_minor?: number
          financially_settled_at?: string | null
          id?: string
          order_number?: string
          order_source?: string
          order_total_minor?: number
          order_type?: string
          organization_id?: string
          payment_policy_code_snapshot?: string | null
          payment_policy_version_snapshot?: string | null
          payment_status?: Database["public"]["Enums"]["payment_status"]
          products_subtotal_minor?: number
          required_deposit_minor?: number
          shipping_address_snapshot?: Json | null
          shipping_charge_minor?: number
          shipping_phone_snapshot?: string | null
          shipping_prepaid_required_snapshot?: boolean | null
          shipping_recipient_name_snapshot?: string | null
          status?: Database["public"]["Enums"]["order_status"]
          terms_frozen_at?: string | null
          updated_at?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "orders_assigned_moderator_id_fkey"
            columns: ["assigned_moderator_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_customer_address_id_fkey"
            columns: ["customer_address_id"]
            isOneToOne: false
            referencedRelation: "customer_addresses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      organizations: {
        Row: {
          created_at: string
          created_by: string | null
          currency_code: string
          display_name: string
          id: string
          is_active: boolean
          is_default: boolean
          legal_name: string | null
          organization_code: string
          timezone_name: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          currency_code?: string
          display_name: string
          id?: string
          is_active?: boolean
          is_default?: boolean
          legal_name?: string | null
          organization_code: string
          timezone_name?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          currency_code?: string
          display_name?: string
          id?: string
          is_active?: boolean
          is_default?: boolean
          legal_name?: string | null
          organization_code?: string
          timezone_name?: string
          updated_at?: string
        }
        Relationships: []
      }
      partner_capital_transactions: {
        Row: {
          accounting_date: string
          amount_minor: number
          approval_request_id: string | null
          created_at: string
          created_by: string
          evidence_attachment_id: string | null
          id: string
          journal_entry_id: string
          organization_id: string
          partner_id: string
          reason: string
          reverses_capital_transaction_id: string | null
          transaction_type: Database["public"]["Enums"]["partner_transaction_type"]
          updated_at: string
          updated_by: string
          wallet_id: string | null
        }
        Insert: {
          accounting_date: string
          amount_minor: number
          approval_request_id?: string | null
          created_at?: string
          created_by: string
          evidence_attachment_id?: string | null
          id?: string
          journal_entry_id: string
          organization_id: string
          partner_id: string
          reason: string
          reverses_capital_transaction_id?: string | null
          transaction_type: Database["public"]["Enums"]["partner_transaction_type"]
          updated_at?: string
          updated_by: string
          wallet_id?: string | null
        }
        Update: {
          accounting_date?: string
          amount_minor?: number
          approval_request_id?: string | null
          created_at?: string
          created_by?: string
          evidence_attachment_id?: string | null
          id?: string
          journal_entry_id?: string
          organization_id?: string
          partner_id?: string
          reason?: string
          reverses_capital_transaction_id?: string | null
          transaction_type?: Database["public"]["Enums"]["partner_transaction_type"]
          updated_at?: string
          updated_by?: string
          wallet_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "partner_capital_transactions_approval_fk"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partner_capital_transactions_approval_org_fk"
            columns: ["organization_id", "approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "partner_capital_transactions_evidence_attachment_id_org_fk"
            columns: ["organization_id", "evidence_attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "partner_capital_transactions_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partner_capital_transactions_partner_fk"
            columns: ["partner_id"]
            isOneToOne: false
            referencedRelation: "partner_account_summary"
            referencedColumns: ["partner_id"]
          },
          {
            foreignKeyName: "partner_capital_transactions_partner_fk"
            columns: ["partner_id"]
            isOneToOne: false
            referencedRelation: "partners"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partner_capital_transactions_partner_org_fk"
            columns: ["organization_id", "partner_id"]
            isOneToOne: false
            referencedRelation: "partner_account_summary"
            referencedColumns: ["organization_id", "partner_id"]
          },
          {
            foreignKeyName: "partner_capital_transactions_partner_org_fk"
            columns: ["organization_id", "partner_id"]
            isOneToOne: false
            referencedRelation: "partners"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "partner_capital_transactions_reversal_fk"
            columns: ["reverses_capital_transaction_id"]
            isOneToOne: false
            referencedRelation: "partner_capital_transactions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partner_capital_transactions_reversal_org_fk"
            columns: ["organization_id", "reverses_capital_transaction_id"]
            isOneToOne: false
            referencedRelation: "partner_capital_transactions"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "partner_capital_transactions_wallet_fk"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["wallet_id"]
          },
          {
            foreignKeyName: "partner_capital_transactions_wallet_fk"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partner_capital_transactions_wallet_org_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["organization_id", "wallet_id"]
          },
          {
            foreignKeyName: "partner_capital_transactions_wallet_org_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      partner_loans: {
        Row: {
          approval_request_id: string | null
          created_at: string
          created_by: string
          direction: string
          due_date: string | null
          id: string
          journal_entry_id: string | null
          loan_no: string
          organization_id: string
          partner_id: string
          principal_minor: number
          repaid_minor: number
          start_date: string
          status: Database["public"]["Enums"]["partner_loan_status"]
          terms_snapshot: Json
          updated_at: string
          updated_by: string
          version: number
        }
        Insert: {
          approval_request_id?: string | null
          created_at?: string
          created_by: string
          direction: string
          due_date?: string | null
          id?: string
          journal_entry_id?: string | null
          loan_no: string
          organization_id: string
          partner_id: string
          principal_minor: number
          repaid_minor?: number
          start_date: string
          status?: Database["public"]["Enums"]["partner_loan_status"]
          terms_snapshot: Json
          updated_at?: string
          updated_by: string
          version?: number
        }
        Update: {
          approval_request_id?: string | null
          created_at?: string
          created_by?: string
          direction?: string
          due_date?: string | null
          id?: string
          journal_entry_id?: string | null
          loan_no?: string
          organization_id?: string
          partner_id?: string
          principal_minor?: number
          repaid_minor?: number
          start_date?: string
          status?: Database["public"]["Enums"]["partner_loan_status"]
          terms_snapshot?: Json
          updated_at?: string
          updated_by?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "partner_loans_approval_fk"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partner_loans_approval_org_fk"
            columns: ["organization_id", "approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "partner_loans_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partner_loans_partner_fk"
            columns: ["partner_id"]
            isOneToOne: false
            referencedRelation: "partner_account_summary"
            referencedColumns: ["partner_id"]
          },
          {
            foreignKeyName: "partner_loans_partner_fk"
            columns: ["partner_id"]
            isOneToOne: false
            referencedRelation: "partners"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partner_loans_partner_org_fk"
            columns: ["organization_id", "partner_id"]
            isOneToOne: false
            referencedRelation: "partner_account_summary"
            referencedColumns: ["organization_id", "partner_id"]
          },
          {
            foreignKeyName: "partner_loans_partner_org_fk"
            columns: ["organization_id", "partner_id"]
            isOneToOne: false
            referencedRelation: "partners"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      partner_ownership_periods: {
        Row: {
          approval_request_id: string | null
          created_at: string
          created_by: string | null
          effective_from: string
          effective_to: string | null
          id: string
          organization_id: string
          ownership_bps: number
          partner_id: string
          profit_share_bps: number
          source_reference: string | null
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          approval_request_id?: string | null
          created_at?: string
          created_by?: string | null
          effective_from: string
          effective_to?: string | null
          id?: string
          organization_id: string
          ownership_bps: number
          partner_id: string
          profit_share_bps: number
          source_reference?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          approval_request_id?: string | null
          created_at?: string
          created_by?: string | null
          effective_from?: string
          effective_to?: string | null
          id?: string
          organization_id?: string
          ownership_bps?: number
          partner_id?: string
          profit_share_bps?: number
          source_reference?: string | null
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "partner_ownership_periods_approval_fk"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partner_ownership_periods_approval_org_fk"
            columns: ["organization_id", "approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "partner_ownership_periods_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partner_ownership_periods_partner_fk"
            columns: ["partner_id"]
            isOneToOne: false
            referencedRelation: "partner_account_summary"
            referencedColumns: ["partner_id"]
          },
          {
            foreignKeyName: "partner_ownership_periods_partner_fk"
            columns: ["partner_id"]
            isOneToOne: false
            referencedRelation: "partners"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partner_ownership_periods_partner_org_fk"
            columns: ["organization_id", "partner_id"]
            isOneToOne: false
            referencedRelation: "partner_account_summary"
            referencedColumns: ["organization_id", "partner_id"]
          },
          {
            foreignKeyName: "partner_ownership_periods_partner_org_fk"
            columns: ["organization_id", "partner_id"]
            isOneToOne: false
            referencedRelation: "partners"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      partner_withdrawals: {
        Row: {
          approval_request_id: string | null
          approval_threshold_minor: number
          approved_at: string | null
          approved_by_partner_id: string | null
          available_source_balance_minor: number | null
          created_at: string
          created_by: string
          evidence_attachment_id: string | null
          executed_at: string | null
          id: string
          journal_entry_id: string | null
          liquidity_snapshot: Json | null
          organization_id: string
          partner_id: string
          reason: string
          request_fingerprint: string
          requested_amount_minor: number
          requested_at: string
          requires_other_partner_approval: boolean
          rolling_24h_existing_minor: number
          rolling_24h_total_minor: number
          safe_withdrawal_amount_minor: number | null
          status: Database["public"]["Enums"]["withdrawal_status"]
          updated_at: string
          updated_by: string
          version: number
          wallet_id: string | null
          withdrawal_no: string
          withdrawal_type: Database["public"]["Enums"]["partner_withdrawal_type"]
        }
        Insert: {
          approval_request_id?: string | null
          approval_threshold_minor: number
          approved_at?: string | null
          approved_by_partner_id?: string | null
          available_source_balance_minor?: number | null
          created_at?: string
          created_by: string
          evidence_attachment_id?: string | null
          executed_at?: string | null
          id?: string
          journal_entry_id?: string | null
          liquidity_snapshot?: Json | null
          organization_id: string
          partner_id: string
          reason: string
          request_fingerprint: string
          requested_amount_minor: number
          requested_at: string
          requires_other_partner_approval: boolean
          rolling_24h_existing_minor?: number
          rolling_24h_total_minor: number
          safe_withdrawal_amount_minor?: number | null
          status?: Database["public"]["Enums"]["withdrawal_status"]
          updated_at?: string
          updated_by: string
          version?: number
          wallet_id?: string | null
          withdrawal_no: string
          withdrawal_type: Database["public"]["Enums"]["partner_withdrawal_type"]
        }
        Update: {
          approval_request_id?: string | null
          approval_threshold_minor?: number
          approved_at?: string | null
          approved_by_partner_id?: string | null
          available_source_balance_minor?: number | null
          created_at?: string
          created_by?: string
          evidence_attachment_id?: string | null
          executed_at?: string | null
          id?: string
          journal_entry_id?: string | null
          liquidity_snapshot?: Json | null
          organization_id?: string
          partner_id?: string
          reason?: string
          request_fingerprint?: string
          requested_amount_minor?: number
          requested_at?: string
          requires_other_partner_approval?: boolean
          rolling_24h_existing_minor?: number
          rolling_24h_total_minor?: number
          safe_withdrawal_amount_minor?: number | null
          status?: Database["public"]["Enums"]["withdrawal_status"]
          updated_at?: string
          updated_by?: string
          version?: number
          wallet_id?: string | null
          withdrawal_no?: string
          withdrawal_type?: Database["public"]["Enums"]["partner_withdrawal_type"]
        }
        Relationships: [
          {
            foreignKeyName: "partner_withdrawals_approval_fk"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partner_withdrawals_approval_org_fk"
            columns: ["organization_id", "approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "partner_withdrawals_approver_partner_fk"
            columns: ["approved_by_partner_id"]
            isOneToOne: false
            referencedRelation: "partner_account_summary"
            referencedColumns: ["partner_id"]
          },
          {
            foreignKeyName: "partner_withdrawals_approver_partner_fk"
            columns: ["approved_by_partner_id"]
            isOneToOne: false
            referencedRelation: "partners"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partner_withdrawals_approver_partner_org_fk"
            columns: ["organization_id", "approved_by_partner_id"]
            isOneToOne: false
            referencedRelation: "partner_account_summary"
            referencedColumns: ["organization_id", "partner_id"]
          },
          {
            foreignKeyName: "partner_withdrawals_approver_partner_org_fk"
            columns: ["organization_id", "approved_by_partner_id"]
            isOneToOne: false
            referencedRelation: "partners"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "partner_withdrawals_evidence_attachment_id_org_fk"
            columns: ["organization_id", "evidence_attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "partner_withdrawals_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partner_withdrawals_partner_fk"
            columns: ["partner_id"]
            isOneToOne: false
            referencedRelation: "partner_account_summary"
            referencedColumns: ["partner_id"]
          },
          {
            foreignKeyName: "partner_withdrawals_partner_fk"
            columns: ["partner_id"]
            isOneToOne: false
            referencedRelation: "partners"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partner_withdrawals_partner_org_fk"
            columns: ["organization_id", "partner_id"]
            isOneToOne: false
            referencedRelation: "partner_account_summary"
            referencedColumns: ["organization_id", "partner_id"]
          },
          {
            foreignKeyName: "partner_withdrawals_partner_org_fk"
            columns: ["organization_id", "partner_id"]
            isOneToOne: false
            referencedRelation: "partners"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "partner_withdrawals_wallet_fk"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["wallet_id"]
          },
          {
            foreignKeyName: "partner_withdrawals_wallet_fk"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partner_withdrawals_wallet_org_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["organization_id", "wallet_id"]
          },
          {
            foreignKeyName: "partner_withdrawals_wallet_org_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      partners: {
        Row: {
          created_at: string
          created_by: string | null
          full_name: string
          id: string
          is_active: boolean
          organization_id: string
          partner_code: string
          profile_id: string | null
          updated_at: string
          updated_by: string | null
          version: number
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          full_name: string
          id?: string
          is_active?: boolean
          organization_id: string
          partner_code: string
          profile_id?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Update: {
          created_at?: string
          created_by?: string | null
          full_name?: string
          id?: string
          is_active?: boolean
          organization_id?: string
          partner_code?: string
          profile_id?: string | null
          updated_at?: string
          updated_by?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "partners_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partners_profile_fk"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "partners_profile_org_fk"
            columns: ["organization_id", "profile_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      payment_allocation_batches: {
        Row: {
          allocated_to_credit_minor: number
          allocated_to_orders_minor: number
          correlation_id: string
          created_at: string
          created_by: string
          customer_payment_id: string
          id: string
          idempotency_key: string
          journal_entry_id: string | null
          organization_id: string
          request_fingerprint: string
          reversal_journal_entry_id: string | null
          reversed_at: string | null
        }
        Insert: {
          allocated_to_credit_minor?: number
          allocated_to_orders_minor: number
          correlation_id: string
          created_at?: string
          created_by: string
          customer_payment_id: string
          id?: string
          idempotency_key: string
          journal_entry_id?: string | null
          organization_id: string
          request_fingerprint: string
          reversal_journal_entry_id?: string | null
          reversed_at?: string | null
        }
        Update: {
          allocated_to_credit_minor?: number
          allocated_to_orders_minor?: number
          correlation_id?: string
          created_at?: string
          created_by?: string
          customer_payment_id?: string
          id?: string
          idempotency_key?: string
          journal_entry_id?: string | null
          organization_id?: string
          request_fingerprint?: string
          reversal_journal_entry_id?: string | null
          reversed_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "payment_allocation_batches_created_by_fk"
            columns: ["organization_id", "created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "payment_allocation_batches_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payment_allocation_batches_payment_fk"
            columns: ["organization_id", "customer_payment_id"]
            isOneToOne: false
            referencedRelation: "customer_payments"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      payment_allocations: {
        Row: {
          allocated_at: string
          allocated_by: string
          allocation_fingerprint: string
          allocation_type: string
          amount_minor: number
          correlation_id: string
          created_at: string
          currency: string
          customer_credit_id: string | null
          customer_id: string
          customer_payment_id: string
          id: string
          order_id: string | null
          organization_id: string
          refund_id: string | null
          reversal_allocation_id: string | null
          reversed_at: string | null
          updated_at: string
        }
        Insert: {
          allocated_at?: string
          allocated_by: string
          allocation_fingerprint: string
          allocation_type: string
          amount_minor: number
          correlation_id: string
          created_at?: string
          currency?: string
          customer_credit_id?: string | null
          customer_id: string
          customer_payment_id: string
          id?: string
          order_id?: string | null
          organization_id: string
          refund_id?: string | null
          reversal_allocation_id?: string | null
          reversed_at?: string | null
          updated_at?: string
        }
        Update: {
          allocated_at?: string
          allocated_by?: string
          allocation_fingerprint?: string
          allocation_type?: string
          amount_minor?: number
          correlation_id?: string
          created_at?: string
          currency?: string
          customer_credit_id?: string | null
          customer_id?: string
          customer_payment_id?: string
          id?: string
          order_id?: string | null
          organization_id?: string
          refund_id?: string | null
          reversal_allocation_id?: string | null
          reversed_at?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "payment_allocations_allocated_by_fkey"
            columns: ["allocated_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payment_allocations_credit_fk"
            columns: ["organization_id", "customer_credit_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "customer_credits"
            referencedColumns: ["organization_id", "id", "customer_id"]
          },
          {
            foreignKeyName: "payment_allocations_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payment_allocations_order_fk"
            columns: ["organization_id", "order_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "order_financial_summary"
            referencedColumns: ["organization_id", "order_id", "customer_id"]
          },
          {
            foreignKeyName: "payment_allocations_order_fk"
            columns: ["organization_id", "order_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["organization_id", "id", "customer_id"]
          },
          {
            foreignKeyName: "payment_allocations_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payment_allocations_payment_fk"
            columns: ["organization_id", "customer_payment_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "customer_payments"
            referencedColumns: ["organization_id", "id", "customer_id"]
          },
          {
            foreignKeyName: "payment_allocations_refund_fk"
            columns: ["organization_id", "refund_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "refunds"
            referencedColumns: ["organization_id", "id", "customer_id"]
          },
          {
            foreignKeyName: "payment_allocations_reversal_fk"
            columns: ["organization_id", "reversal_allocation_id"]
            isOneToOne: false
            referencedRelation: "payment_allocations"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      payment_reversal_events: {
        Row: {
          correlation_id: string
          customer_payment_id: string
          id: string
          idempotency_key: string
          organization_id: string
          reason: string
          receipt_reversal_journal_entry_id: string
          request_fingerprint: string
          reversed_at: string
          reversed_by: string
        }
        Insert: {
          correlation_id: string
          customer_payment_id: string
          id?: string
          idempotency_key: string
          organization_id: string
          reason: string
          receipt_reversal_journal_entry_id: string
          request_fingerprint: string
          reversed_at?: string
          reversed_by: string
        }
        Update: {
          correlation_id?: string
          customer_payment_id?: string
          id?: string
          idempotency_key?: string
          organization_id?: string
          reason?: string
          receipt_reversal_journal_entry_id?: string
          request_fingerprint?: string
          reversed_at?: string
          reversed_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "payment_reversal_events_actor_fk"
            columns: ["organization_id", "reversed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "payment_reversal_events_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payment_reversal_events_payment_fk"
            columns: ["organization_id", "customer_payment_id"]
            isOneToOne: true
            referencedRelation: "customer_payments"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      payroll_entries: {
        Row: {
          accrual_journal_entry_id: string | null
          advance_deductions_minor: number
          approval_request_id: string | null
          approved_allowances_minor: number
          approved_at: string | null
          approved_by: string | null
          approved_deductions_minor: number
          base_salary_minor: number
          bonus_minor: number
          bonus_scheme_snapshot: Json | null
          compensation_snapshot: Json
          created_at: string
          created_by: string
          deduction_snapshot: Json
          employee_id: string
          employee_performance_review_id: string | null
          id: string
          net_payroll_minor: number
          organization_id: string
          paid_minor: number
          payroll_period_id: string
          status: Database["public"]["Enums"]["payroll_status"]
          updated_at: string
          updated_by: string
          version: number
        }
        Insert: {
          accrual_journal_entry_id?: string | null
          advance_deductions_minor?: number
          approval_request_id?: string | null
          approved_allowances_minor?: number
          approved_at?: string | null
          approved_by?: string | null
          approved_deductions_minor?: number
          base_salary_minor: number
          bonus_minor?: number
          bonus_scheme_snapshot?: Json | null
          compensation_snapshot: Json
          created_at?: string
          created_by: string
          deduction_snapshot?: Json
          employee_id: string
          employee_performance_review_id?: string | null
          id?: string
          net_payroll_minor: number
          organization_id: string
          paid_minor?: number
          payroll_period_id: string
          status?: Database["public"]["Enums"]["payroll_status"]
          updated_at?: string
          updated_by: string
          version?: number
        }
        Update: {
          accrual_journal_entry_id?: string | null
          advance_deductions_minor?: number
          approval_request_id?: string | null
          approved_allowances_minor?: number
          approved_at?: string | null
          approved_by?: string | null
          approved_deductions_minor?: number
          base_salary_minor?: number
          bonus_minor?: number
          bonus_scheme_snapshot?: Json | null
          compensation_snapshot?: Json
          created_at?: string
          created_by?: string
          deduction_snapshot?: Json
          employee_id?: string
          employee_performance_review_id?: string | null
          id?: string
          net_payroll_minor?: number
          organization_id?: string
          paid_minor?: number
          payroll_period_id?: string
          status?: Database["public"]["Enums"]["payroll_status"]
          updated_at?: string
          updated_by?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "payroll_entries_approval_fk"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payroll_entries_approval_org_fk"
            columns: ["organization_id", "approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "payroll_entries_employee_fk"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payroll_entries_employee_org_fk"
            columns: ["organization_id", "employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "payroll_entries_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payroll_entries_period_fk"
            columns: ["payroll_period_id"]
            isOneToOne: false
            referencedRelation: "payroll_periods"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payroll_entries_period_org_fk"
            columns: ["organization_id", "payroll_period_id"]
            isOneToOne: false
            referencedRelation: "payroll_periods"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "payroll_entries_review_fk"
            columns: ["employee_performance_review_id"]
            isOneToOne: false
            referencedRelation: "employee_performance_reviews"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payroll_entries_review_org_fk"
            columns: ["organization_id", "employee_performance_review_id"]
            isOneToOne: false
            referencedRelation: "employee_performance_reviews"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      payroll_payments: {
        Row: {
          amount_minor: number
          created_at: string
          created_by: string
          evidence_attachment_id: string | null
          id: string
          journal_entry_id: string
          organization_id: string
          payment_date: string
          payroll_entry_id: string
          provider_reference: string
          reverses_payroll_payment_id: string | null
          updated_at: string
          updated_by: string
          wallet_id: string
        }
        Insert: {
          amount_minor: number
          created_at?: string
          created_by: string
          evidence_attachment_id?: string | null
          id?: string
          journal_entry_id: string
          organization_id: string
          payment_date: string
          payroll_entry_id: string
          provider_reference: string
          reverses_payroll_payment_id?: string | null
          updated_at?: string
          updated_by: string
          wallet_id: string
        }
        Update: {
          amount_minor?: number
          created_at?: string
          created_by?: string
          evidence_attachment_id?: string | null
          id?: string
          journal_entry_id?: string
          organization_id?: string
          payment_date?: string
          payroll_entry_id?: string
          provider_reference?: string
          reverses_payroll_payment_id?: string | null
          updated_at?: string
          updated_by?: string
          wallet_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "payroll_payments_entry_fk"
            columns: ["payroll_entry_id"]
            isOneToOne: false
            referencedRelation: "payroll_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payroll_payments_entry_org_fk"
            columns: ["organization_id", "payroll_entry_id"]
            isOneToOne: false
            referencedRelation: "payroll_entries"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "payroll_payments_evidence_attachment_id_org_fk"
            columns: ["organization_id", "evidence_attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "payroll_payments_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payroll_payments_reversal_fk"
            columns: ["reverses_payroll_payment_id"]
            isOneToOne: false
            referencedRelation: "payroll_payments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payroll_payments_reversal_org_fk"
            columns: ["organization_id", "reverses_payroll_payment_id"]
            isOneToOne: false
            referencedRelation: "payroll_payments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "payroll_payments_wallet_fk"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["wallet_id"]
          },
          {
            foreignKeyName: "payroll_payments_wallet_fk"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payroll_payments_wallet_org_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["organization_id", "wallet_id"]
          },
          {
            foreignKeyName: "payroll_payments_wallet_org_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      payroll_periods: {
        Row: {
          approval_request_id: string | null
          approved_at: string | null
          approved_by: string | null
          calculation_policy_snapshot: Json
          created_at: string
          created_by: string
          due_date: string
          id: string
          organization_id: string
          payment_deadline: string
          period_end: string
          period_start: string
          source_cutoff_at: string
          status: Database["public"]["Enums"]["payroll_status"]
          updated_at: string
          updated_by: string
          version: number
        }
        Insert: {
          approval_request_id?: string | null
          approved_at?: string | null
          approved_by?: string | null
          calculation_policy_snapshot: Json
          created_at?: string
          created_by: string
          due_date: string
          id?: string
          organization_id: string
          payment_deadline: string
          period_end: string
          period_start: string
          source_cutoff_at: string
          status?: Database["public"]["Enums"]["payroll_status"]
          updated_at?: string
          updated_by: string
          version?: number
        }
        Update: {
          approval_request_id?: string | null
          approved_at?: string | null
          approved_by?: string | null
          calculation_policy_snapshot?: Json
          created_at?: string
          created_by?: string
          due_date?: string
          id?: string
          organization_id?: string
          payment_deadline?: string
          period_end?: string
          period_start?: string
          source_cutoff_at?: string
          status?: Database["public"]["Enums"]["payroll_status"]
          updated_at?: string
          updated_by?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "payroll_periods_approval_request_fk"
            columns: ["organization_id", "approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "payroll_periods_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      phone_brands: {
        Row: {
          archived_at: string | null
          brand_code: string
          created_at: string
          created_by: string | null
          display_name: string
          id: string
          is_active: boolean
          organization_id: string
          updated_at: string
        }
        Insert: {
          archived_at?: string | null
          brand_code: string
          created_at?: string
          created_by?: string | null
          display_name: string
          id?: string
          is_active?: boolean
          organization_id: string
          updated_at?: string
        }
        Update: {
          archived_at?: string | null
          brand_code?: string
          created_at?: string
          created_by?: string | null
          display_name?: string
          id?: string
          is_active?: boolean
          organization_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "phone_brands_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      phone_models: {
        Row: {
          archived_at: string | null
          cost_risk_warning: boolean
          created_at: string
          created_by: string | null
          display_name: string
          id: string
          is_active: boolean
          model_code: string
          organization_id: string
          phone_brand_id: string
          release_year: number | null
          risk_note: string | null
          updated_at: string
        }
        Insert: {
          archived_at?: string | null
          cost_risk_warning?: boolean
          created_at?: string
          created_by?: string | null
          display_name: string
          id?: string
          is_active?: boolean
          model_code: string
          organization_id: string
          phone_brand_id: string
          release_year?: number | null
          risk_note?: string | null
          updated_at?: string
        }
        Update: {
          archived_at?: string | null
          cost_risk_warning?: boolean
          created_at?: string
          created_by?: string | null
          display_name?: string
          id?: string
          is_active?: boolean
          model_code?: string
          organization_id?: string
          phone_brand_id?: string
          release_year?: number | null
          risk_note?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "phone_models_brand_org_fk"
            columns: ["organization_id", "phone_brand_id"]
            isOneToOne: false
            referencedRelation: "phone_brands"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "phone_models_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      print_batch_items: {
        Row: {
          accepted_quantity: number
          actual_accepted_unit_cost_minor: number | null
          attempt_no: number
          closed_at: string | null
          created_at: string
          created_by: string
          expected_case_unit_cost_minor: number
          expected_print_unit_cost_minor: number
          expected_total_unit_cost_minor: number
          id: string
          issue_reason: string | null
          lost_quantity: number
          order_item_id: string
          organization_id: string
          print_batch_id: string
          qc_completed_at: string | null
          queued_at: string | null
          received_quantity: number
          rejected_quantity: number
          replaces_print_batch_item_id: string | null
          requested_quantity: number
          responsibility: string | null
          sent_at: string | null
          sent_quantity: number
          status: Database["public"]["Enums"]["production_attempt_status"]
          supplier_price_rule_id: string | null
          supply_method: Database["public"]["Enums"]["supply_method"]
          updated_at: string
          updated_by: string
          version: number
        }
        Insert: {
          accepted_quantity?: number
          actual_accepted_unit_cost_minor?: number | null
          attempt_no: number
          closed_at?: string | null
          created_at?: string
          created_by: string
          expected_case_unit_cost_minor?: number
          expected_print_unit_cost_minor?: number
          expected_total_unit_cost_minor: number
          id?: string
          issue_reason?: string | null
          lost_quantity?: number
          order_item_id: string
          organization_id: string
          print_batch_id: string
          qc_completed_at?: string | null
          queued_at?: string | null
          received_quantity?: number
          rejected_quantity?: number
          replaces_print_batch_item_id?: string | null
          requested_quantity: number
          responsibility?: string | null
          sent_at?: string | null
          sent_quantity?: number
          status?: Database["public"]["Enums"]["production_attempt_status"]
          supplier_price_rule_id?: string | null
          supply_method: Database["public"]["Enums"]["supply_method"]
          updated_at?: string
          updated_by: string
          version?: number
        }
        Update: {
          accepted_quantity?: number
          actual_accepted_unit_cost_minor?: number | null
          attempt_no?: number
          closed_at?: string | null
          created_at?: string
          created_by?: string
          expected_case_unit_cost_minor?: number
          expected_print_unit_cost_minor?: number
          expected_total_unit_cost_minor?: number
          id?: string
          issue_reason?: string | null
          lost_quantity?: number
          order_item_id?: string
          organization_id?: string
          print_batch_id?: string
          qc_completed_at?: string | null
          queued_at?: string | null
          received_quantity?: number
          rejected_quantity?: number
          replaces_print_batch_item_id?: string | null
          requested_quantity?: number
          responsibility?: string | null
          sent_at?: string | null
          sent_quantity?: number
          status?: Database["public"]["Enums"]["production_attempt_status"]
          supplier_price_rule_id?: string | null
          supply_method?: Database["public"]["Enums"]["supply_method"]
          updated_at?: string
          updated_by?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "print_batch_items_batch_fk"
            columns: ["print_batch_id"]
            isOneToOne: false
            referencedRelation: "print_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "print_batch_items_batch_org_fk"
            columns: ["organization_id", "print_batch_id"]
            isOneToOne: false
            referencedRelation: "print_batches"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "print_batch_items_order_item_fk"
            columns: ["order_item_id"]
            isOneToOne: false
            referencedRelation: "order_item_margin_summary"
            referencedColumns: ["order_item_id"]
          },
          {
            foreignKeyName: "print_batch_items_order_item_fk"
            columns: ["order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "print_batch_items_order_item_org_fk"
            columns: ["organization_id", "order_item_id"]
            isOneToOne: false
            referencedRelation: "order_item_margin_summary"
            referencedColumns: ["organization_id", "order_item_id"]
          },
          {
            foreignKeyName: "print_batch_items_order_item_org_fk"
            columns: ["organization_id", "order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "print_batch_items_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "print_batch_items_price_rule_fk"
            columns: ["supplier_price_rule_id"]
            isOneToOne: false
            referencedRelation: "supplier_price_rules"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "print_batch_items_replaced_attempt_fk"
            columns: ["replaces_print_batch_item_id"]
            isOneToOne: false
            referencedRelation: "print_batch_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "print_batch_items_replaced_attempt_org_fk"
            columns: ["organization_id", "replaces_print_batch_item_id"]
            isOneToOne: false
            referencedRelation: "print_batch_items"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      print_batch_qc_events: {
        Row: {
          accepted_quantity: number
          created_at: string
          created_by: string
          id: string
          inspected_at: string
          inspected_by: string
          inspected_quantity: number
          organization_id: string
          print_batch_item_id: string
          print_batch_receipt_item_id: string
          rejected_quantity: number
          rejection_reason: string | null
          responsibility: string | null
          status: Database["public"]["Enums"]["qc_status"]
          updated_at: string
          updated_by: string
        }
        Insert: {
          accepted_quantity?: number
          created_at?: string
          created_by: string
          id?: string
          inspected_at: string
          inspected_by: string
          inspected_quantity: number
          organization_id: string
          print_batch_item_id: string
          print_batch_receipt_item_id: string
          rejected_quantity?: number
          rejection_reason?: string | null
          responsibility?: string | null
          status: Database["public"]["Enums"]["qc_status"]
          updated_at?: string
          updated_by: string
        }
        Update: {
          accepted_quantity?: number
          created_at?: string
          created_by?: string
          id?: string
          inspected_at?: string
          inspected_by?: string
          inspected_quantity?: number
          organization_id?: string
          print_batch_item_id?: string
          print_batch_receipt_item_id?: string
          rejected_quantity?: number
          rejection_reason?: string | null
          responsibility?: string | null
          status?: Database["public"]["Enums"]["qc_status"]
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "print_batch_qc_events_batch_item_fk"
            columns: ["print_batch_item_id"]
            isOneToOne: false
            referencedRelation: "print_batch_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "print_batch_qc_events_batch_item_org_fk"
            columns: ["organization_id", "print_batch_item_id"]
            isOneToOne: false
            referencedRelation: "print_batch_items"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "print_batch_qc_events_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "print_batch_qc_events_receipt_item_fk"
            columns: ["print_batch_receipt_item_id"]
            isOneToOne: false
            referencedRelation: "print_batch_receipt_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "print_batch_qc_events_receipt_item_org_fk"
            columns: ["organization_id", "print_batch_receipt_item_id"]
            isOneToOne: false
            referencedRelation: "print_batch_receipt_items"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      print_batch_receipt_items: {
        Row: {
          condition_notes: string | null
          created_at: string
          created_by: string
          id: string
          observed_lost_quantity: number
          organization_id: string
          print_batch_item_id: string
          print_batch_receipt_id: string
          received_quantity: number
          updated_at: string
          updated_by: string
        }
        Insert: {
          condition_notes?: string | null
          created_at?: string
          created_by: string
          id?: string
          observed_lost_quantity?: number
          organization_id: string
          print_batch_item_id: string
          print_batch_receipt_id: string
          received_quantity: number
          updated_at?: string
          updated_by: string
        }
        Update: {
          condition_notes?: string | null
          created_at?: string
          created_by?: string
          id?: string
          observed_lost_quantity?: number
          organization_id?: string
          print_batch_item_id?: string
          print_batch_receipt_id?: string
          received_quantity?: number
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "print_batch_receipt_items_batch_item_fk"
            columns: ["print_batch_item_id"]
            isOneToOne: false
            referencedRelation: "print_batch_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "print_batch_receipt_items_batch_item_org_fk"
            columns: ["organization_id", "print_batch_item_id"]
            isOneToOne: false
            referencedRelation: "print_batch_items"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "print_batch_receipt_items_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "print_batch_receipt_items_receipt_fk"
            columns: ["print_batch_receipt_id"]
            isOneToOne: false
            referencedRelation: "print_batch_receipts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "print_batch_receipt_items_receipt_org_fk"
            columns: ["organization_id", "print_batch_receipt_id"]
            isOneToOne: false
            referencedRelation: "print_batch_receipts"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      print_batch_receipts: {
        Row: {
          created_at: string
          created_by: string
          id: string
          notes: string | null
          organization_id: string
          print_batch_id: string
          receipt_no: string
          received_at: string
          received_by: string
          supplier_document_ref: string | null
          updated_at: string
          updated_by: string
        }
        Insert: {
          created_at?: string
          created_by: string
          id?: string
          notes?: string | null
          organization_id: string
          print_batch_id: string
          receipt_no: string
          received_at: string
          received_by: string
          supplier_document_ref?: string | null
          updated_at?: string
          updated_by: string
        }
        Update: {
          created_at?: string
          created_by?: string
          id?: string
          notes?: string | null
          organization_id?: string
          print_batch_id?: string
          receipt_no?: string
          received_at?: string
          received_by?: string
          supplier_document_ref?: string | null
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "print_batch_receipts_batch_fk"
            columns: ["print_batch_id"]
            isOneToOne: false
            referencedRelation: "print_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "print_batch_receipts_batch_org_fk"
            columns: ["organization_id", "print_batch_id"]
            isOneToOne: false
            referencedRelation: "print_batches"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "print_batch_receipts_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      print_batches: {
        Row: {
          acknowledged_at: string | null
          batch_no: string
          business_date: string
          cancellation_reason: string | null
          cancelled_at: string | null
          closed_at: string | null
          created_at: string
          created_by: string
          currency_code: string
          id: string
          notes: string | null
          organization_id: string
          sent_at: string | null
          status: Database["public"]["Enums"]["print_batch_status"]
          supplier_id: string
          updated_at: string
          updated_by: string
          version: number
        }
        Insert: {
          acknowledged_at?: string | null
          batch_no: string
          business_date: string
          cancellation_reason?: string | null
          cancelled_at?: string | null
          closed_at?: string | null
          created_at?: string
          created_by: string
          currency_code?: string
          id?: string
          notes?: string | null
          organization_id: string
          sent_at?: string | null
          status?: Database["public"]["Enums"]["print_batch_status"]
          supplier_id: string
          updated_at?: string
          updated_by: string
          version?: number
        }
        Update: {
          acknowledged_at?: string | null
          batch_no?: string
          business_date?: string
          cancellation_reason?: string | null
          cancelled_at?: string | null
          closed_at?: string | null
          created_at?: string
          created_by?: string
          currency_code?: string
          id?: string
          notes?: string | null
          organization_id?: string
          sent_at?: string | null
          status?: Database["public"]["Enums"]["print_batch_status"]
          supplier_id?: string
          updated_at?: string
          updated_by?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "print_batches_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "print_batches_supplier_fk"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "print_batches_supplier_org_fk"
            columns: ["organization_id", "supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      product_categories: {
        Row: {
          archived_at: string | null
          category_code: string
          created_at: string
          created_by: string | null
          description: string | null
          display_name: string
          id: string
          is_active: boolean
          organization_id: string
          parent_category_id: string | null
          updated_at: string
        }
        Insert: {
          archived_at?: string | null
          category_code: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          display_name: string
          id?: string
          is_active?: boolean
          organization_id: string
          parent_category_id?: string | null
          updated_at?: string
        }
        Update: {
          archived_at?: string | null
          category_code?: string
          created_at?: string
          created_by?: string | null
          description?: string | null
          display_name?: string
          id?: string
          is_active?: boolean
          organization_id?: string
          parent_category_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_categories_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_categories_parent_org_fk"
            columns: ["organization_id", "parent_category_id"]
            isOneToOne: false
            referencedRelation: "product_categories"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      product_price_rules: {
        Row: {
          created_at: string
          created_by: string | null
          currency_code: string
          effective_from: string
          effective_to: string | null
          id: string
          is_active: boolean
          notes: string | null
          organization_id: string
          priority: number
          product_variant_id: string
          sale_price_minor: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          currency_code?: string
          effective_from: string
          effective_to?: string | null
          id?: string
          is_active?: boolean
          notes?: string | null
          organization_id: string
          priority?: number
          product_variant_id: string
          sale_price_minor: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          currency_code?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_active?: boolean
          notes?: string | null
          organization_id?: string
          priority?: number
          product_variant_id?: string
          sale_price_minor?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_price_rules_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_price_rules_variant_org_fk"
            columns: ["organization_id", "product_variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      product_variants: {
        Row: {
          archived_at: string | null
          attributes: Json
          barcode: string | null
          created_at: string
          created_by: string | null
          display_name: string
          id: string
          is_active: boolean
          organization_id: string
          phone_model_id: string | null
          product_id: string
          sku: string | null
          updated_at: string
          variant_code: string
        }
        Insert: {
          archived_at?: string | null
          attributes?: Json
          barcode?: string | null
          created_at?: string
          created_by?: string | null
          display_name: string
          id?: string
          is_active?: boolean
          organization_id: string
          phone_model_id?: string | null
          product_id: string
          sku?: string | null
          updated_at?: string
          variant_code: string
        }
        Update: {
          archived_at?: string | null
          attributes?: Json
          barcode?: string | null
          created_at?: string
          created_by?: string | null
          display_name?: string
          id?: string
          is_active?: boolean
          organization_id?: string
          phone_model_id?: string | null
          product_id?: string
          sku?: string | null
          updated_at?: string
          variant_code?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_variants_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_variants_phone_model_org_fk"
            columns: ["organization_id", "phone_model_id"]
            isOneToOne: false
            referencedRelation: "phone_models"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "product_variants_product_org_fk"
            columns: ["organization_id", "product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      products: {
        Row: {
          archived_at: string | null
          created_at: string
          created_by: string | null
          default_item_type: Database["public"]["Enums"]["item_type"]
          description: string | null
          display_name: string
          id: string
          is_active: boolean
          organization_id: string
          product_category_id: string | null
          product_code: string
          product_kind: string
          requires_phone_model: boolean
          tracks_inventory: boolean
          updated_at: string
        }
        Insert: {
          archived_at?: string | null
          created_at?: string
          created_by?: string | null
          default_item_type: Database["public"]["Enums"]["item_type"]
          description?: string | null
          display_name: string
          id?: string
          is_active?: boolean
          organization_id: string
          product_category_id?: string | null
          product_code: string
          product_kind: string
          requires_phone_model?: boolean
          tracks_inventory?: boolean
          updated_at?: string
        }
        Update: {
          archived_at?: string | null
          created_at?: string
          created_by?: string | null
          default_item_type?: Database["public"]["Enums"]["item_type"]
          description?: string | null
          display_name?: string
          id?: string
          is_active?: boolean
          organization_id?: string
          product_category_id?: string | null
          product_code?: string
          product_kind?: string
          requires_phone_model?: boolean
          tracks_inventory?: boolean
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "products_category_org_fk"
            columns: ["organization_id", "product_category_id"]
            isOneToOne: false
            referencedRelation: "product_categories"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "products_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          activated_at: string | null
          activated_by: string | null
          created_at: string
          display_name: string
          employee_reference: string | null
          full_name: string | null
          id: string
          last_seen_at: string | null
          organization_id: string
          role: string
          status: Database["public"]["Enums"]["user_status"]
          status_reason: string | null
          suspended_at: string | null
          suspended_by: string | null
          updated_at: string
        }
        Insert: {
          activated_at?: string | null
          activated_by?: string | null
          created_at?: string
          display_name: string
          employee_reference?: string | null
          full_name?: string | null
          id: string
          last_seen_at?: string | null
          organization_id: string
          role?: string
          status?: Database["public"]["Enums"]["user_status"]
          status_reason?: string | null
          suspended_at?: string | null
          suspended_by?: string | null
          updated_at?: string
        }
        Update: {
          activated_at?: string | null
          activated_by?: string | null
          created_at?: string
          display_name?: string
          employee_reference?: string | null
          full_name?: string | null
          id?: string
          last_seen_at?: string | null
          organization_id?: string
          role?: string
          status?: Database["public"]["Enums"]["user_status"]
          status_reason?: string | null
          suspended_at?: string | null
          suspended_by?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "profiles_activated_by_org_fk"
            columns: ["organization_id", "activated_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "profiles_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profiles_suspended_by_org_fk"
            columns: ["organization_id", "suspended_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      profit_distribution_lines: {
        Row: {
          allocated_amount_minor: number
          allocation_numerator: number
          created_at: string
          created_by: string
          id: string
          organization_id: string
          ownership_bps_snapshot: number
          partner_id: string
          profit_distribution_id: string
          updated_at: string
          updated_by: string
        }
        Insert: {
          allocated_amount_minor: number
          allocation_numerator: number
          created_at?: string
          created_by: string
          id?: string
          organization_id: string
          ownership_bps_snapshot: number
          partner_id: string
          profit_distribution_id: string
          updated_at?: string
          updated_by: string
        }
        Update: {
          allocated_amount_minor?: number
          allocation_numerator?: number
          created_at?: string
          created_by?: string
          id?: string
          organization_id?: string
          ownership_bps_snapshot?: number
          partner_id?: string
          profit_distribution_id?: string
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "profit_distribution_lines_distribution_fk"
            columns: ["profit_distribution_id"]
            isOneToOne: false
            referencedRelation: "profit_distributions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profit_distribution_lines_distribution_org_fk"
            columns: ["organization_id", "profit_distribution_id"]
            isOneToOne: false
            referencedRelation: "profit_distributions"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "profit_distribution_lines_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profit_distribution_lines_partner_fk"
            columns: ["partner_id"]
            isOneToOne: false
            referencedRelation: "partner_account_summary"
            referencedColumns: ["partner_id"]
          },
          {
            foreignKeyName: "profit_distribution_lines_partner_fk"
            columns: ["partner_id"]
            isOneToOne: false
            referencedRelation: "partners"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profit_distribution_lines_partner_org_fk"
            columns: ["organization_id", "partner_id"]
            isOneToOne: false
            referencedRelation: "partner_account_summary"
            referencedColumns: ["organization_id", "partner_id"]
          },
          {
            foreignKeyName: "profit_distribution_lines_partner_org_fk"
            columns: ["organization_id", "partner_id"]
            isOneToOne: false
            referencedRelation: "partners"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      profit_distributions: {
        Row: {
          allocated_minor: number
          approval_request_id: string | null
          approved_at: string | null
          approved_by: string | null
          approved_distribution_minor: number
          created_at: string
          created_by: string
          distributable_profit_minor: number
          distribution_no: string
          id: string
          journal_entry_id: string | null
          monthly_closing_id: string
          organization_id: string
          ownership_snapshot_at: string
          posted_at: string | null
          purpose: string
          retained_remainder_minor: number
          status: Database["public"]["Enums"]["profit_distribution_status"]
          updated_at: string
          updated_by: string
          version: number
        }
        Insert: {
          allocated_minor?: number
          approval_request_id?: string | null
          approved_at?: string | null
          approved_by?: string | null
          approved_distribution_minor: number
          created_at?: string
          created_by: string
          distributable_profit_minor: number
          distribution_no: string
          id?: string
          journal_entry_id?: string | null
          monthly_closing_id: string
          organization_id: string
          ownership_snapshot_at: string
          posted_at?: string | null
          purpose?: string
          retained_remainder_minor?: number
          status?: Database["public"]["Enums"]["profit_distribution_status"]
          updated_at?: string
          updated_by: string
          version?: number
        }
        Update: {
          allocated_minor?: number
          approval_request_id?: string | null
          approved_at?: string | null
          approved_by?: string | null
          approved_distribution_minor?: number
          created_at?: string
          created_by?: string
          distributable_profit_minor?: number
          distribution_no?: string
          id?: string
          journal_entry_id?: string | null
          monthly_closing_id?: string
          organization_id?: string
          ownership_snapshot_at?: string
          posted_at?: string | null
          purpose?: string
          retained_remainder_minor?: number
          status?: Database["public"]["Enums"]["profit_distribution_status"]
          updated_at?: string
          updated_by?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "profit_distributions_approval_fk"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profit_distributions_approval_org_fk"
            columns: ["organization_id", "approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "profit_distributions_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      refunds: {
        Row: {
          approval_journal_entry_id: string | null
          approval_request_id: string | null
          approval_reversal_journal_entry_id: string | null
          approval_subject_fingerprint: string | null
          approved_amount_minor: number | null
          approved_at: string | null
          approved_by: string | null
          cancelled_at: string | null
          correlation_id: string
          created_at: string
          currency: string
          customer_credit_id: string | null
          customer_id: string
          customer_payment_id: string | null
          destination_method: string | null
          destination_reference_snapshot: string | null
          evidence_attachment_id: string | null
          executed_amount_minor: number
          executed_at: string | null
          executed_by: string | null
          execution_journal_entry_id: string | null
          execution_reversal_journal_entry_id: string | null
          external_transaction_reference: string | null
          id: string
          idempotency_key: string
          order_id: string | null
          organization_id: string
          reason: string
          request_fingerprint: string
          requested_amount_minor: number
          requested_at: string
          requested_by: string
          reversal_journal_entry_id: string | null
          reversed_at: string | null
          source_wallet_id: string | null
          status: string
          updated_at: string
        }
        Insert: {
          approval_journal_entry_id?: string | null
          approval_request_id?: string | null
          approval_reversal_journal_entry_id?: string | null
          approval_subject_fingerprint?: string | null
          approved_amount_minor?: number | null
          approved_at?: string | null
          approved_by?: string | null
          cancelled_at?: string | null
          correlation_id: string
          created_at?: string
          currency?: string
          customer_credit_id?: string | null
          customer_id: string
          customer_payment_id?: string | null
          destination_method?: string | null
          destination_reference_snapshot?: string | null
          evidence_attachment_id?: string | null
          executed_amount_minor?: number
          executed_at?: string | null
          executed_by?: string | null
          execution_journal_entry_id?: string | null
          execution_reversal_journal_entry_id?: string | null
          external_transaction_reference?: string | null
          id?: string
          idempotency_key: string
          order_id?: string | null
          organization_id: string
          reason: string
          request_fingerprint: string
          requested_amount_minor: number
          requested_at?: string
          requested_by: string
          reversal_journal_entry_id?: string | null
          reversed_at?: string | null
          source_wallet_id?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          approval_journal_entry_id?: string | null
          approval_request_id?: string | null
          approval_reversal_journal_entry_id?: string | null
          approval_subject_fingerprint?: string | null
          approved_amount_minor?: number | null
          approved_at?: string | null
          approved_by?: string | null
          cancelled_at?: string | null
          correlation_id?: string
          created_at?: string
          currency?: string
          customer_credit_id?: string | null
          customer_id?: string
          customer_payment_id?: string | null
          destination_method?: string | null
          destination_reference_snapshot?: string | null
          evidence_attachment_id?: string | null
          executed_amount_minor?: number
          executed_at?: string | null
          executed_by?: string | null
          execution_journal_entry_id?: string | null
          execution_reversal_journal_entry_id?: string | null
          external_transaction_reference?: string | null
          id?: string
          idempotency_key?: string
          order_id?: string | null
          organization_id?: string
          reason?: string
          request_fingerprint?: string
          requested_amount_minor?: number
          requested_at?: string
          requested_by?: string
          reversal_journal_entry_id?: string | null
          reversed_at?: string | null
          source_wallet_id?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "refunds_approval_request_id_fkey"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refunds_approved_by_fkey"
            columns: ["approved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refunds_credit_fk"
            columns: ["organization_id", "customer_credit_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "customer_credits"
            referencedColumns: ["organization_id", "id", "customer_id"]
          },
          {
            foreignKeyName: "refunds_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refunds_evidence_attachment_id_org_fk"
            columns: ["organization_id", "evidence_attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "refunds_executed_by_fkey"
            columns: ["executed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refunds_order_fk"
            columns: ["organization_id", "order_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "order_financial_summary"
            referencedColumns: ["organization_id", "order_id", "customer_id"]
          },
          {
            foreignKeyName: "refunds_order_fk"
            columns: ["organization_id", "order_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["organization_id", "id", "customer_id"]
          },
          {
            foreignKeyName: "refunds_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refunds_payment_fk"
            columns: ["organization_id", "customer_payment_id", "customer_id"]
            isOneToOne: false
            referencedRelation: "customer_payments"
            referencedColumns: ["organization_id", "id", "customer_id"]
          },
          {
            foreignKeyName: "refunds_requested_by_fkey"
            columns: ["requested_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "refunds_wallet_fk"
            columns: ["organization_id", "source_wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["organization_id", "wallet_id"]
          },
          {
            foreignKeyName: "refunds_wallet_fk"
            columns: ["organization_id", "source_wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      return_items: {
        Row: {
          created_at: string
          created_by: string
          disposition: Database["public"]["Enums"]["return_disposition"]
          id: string
          inventory_movement_id: string | null
          operational_error_cost_minor: number
          organization_id: string
          packaging_loss_minor: number
          product_loss_minor: number
          quantity: number
          reason: string
          refundable_amount_minor: number
          reprint_cost_minor: number
          return_id: string
          shipment_item_id: string
          updated_at: string
          updated_by: string
        }
        Insert: {
          created_at?: string
          created_by: string
          disposition?: Database["public"]["Enums"]["return_disposition"]
          id?: string
          inventory_movement_id?: string | null
          operational_error_cost_minor?: number
          organization_id: string
          packaging_loss_minor?: number
          product_loss_minor?: number
          quantity: number
          reason: string
          refundable_amount_minor?: number
          reprint_cost_minor?: number
          return_id: string
          shipment_item_id: string
          updated_at?: string
          updated_by: string
        }
        Update: {
          created_at?: string
          created_by?: string
          disposition?: Database["public"]["Enums"]["return_disposition"]
          id?: string
          inventory_movement_id?: string | null
          operational_error_cost_minor?: number
          organization_id?: string
          packaging_loss_minor?: number
          product_loss_minor?: number
          quantity?: number
          reason?: string
          refundable_amount_minor?: number
          reprint_cost_minor?: number
          return_id?: string
          shipment_item_id?: string
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "return_items_inventory_movement_fk"
            columns: ["inventory_movement_id"]
            isOneToOne: false
            referencedRelation: "inventory_movements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "return_items_inventory_movement_org_fk"
            columns: ["organization_id", "inventory_movement_id"]
            isOneToOne: false
            referencedRelation: "inventory_movements"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "return_items_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "return_items_return_fk"
            columns: ["return_id"]
            isOneToOne: false
            referencedRelation: "returns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "return_items_return_org_fk"
            columns: ["organization_id", "return_id"]
            isOneToOne: false
            referencedRelation: "returns"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "return_items_shipment_item_fk"
            columns: ["shipment_item_id"]
            isOneToOne: false
            referencedRelation: "shipment_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "return_items_shipment_item_org_fk"
            columns: ["organization_id", "shipment_item_id"]
            isOneToOne: false
            referencedRelation: "shipment_items"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      returns: {
        Row: {
          courier_return_fee_minor: number
          created_at: string
          created_by: string
          customer_credit_id: string | null
          evidence_attachment_id: string | null
          id: string
          inspected_at: string | null
          journal_entry_id: string | null
          organization_id: string
          reason: string
          received_at: string | null
          requested_at: string
          return_no: string
          shipment_id: string
          status: string
          total_business_loss_minor: number
          updated_at: string
          updated_by: string
          version: number
        }
        Insert: {
          courier_return_fee_minor?: number
          created_at?: string
          created_by: string
          customer_credit_id?: string | null
          evidence_attachment_id?: string | null
          id?: string
          inspected_at?: string | null
          journal_entry_id?: string | null
          organization_id: string
          reason: string
          received_at?: string | null
          requested_at: string
          return_no: string
          shipment_id: string
          status?: string
          total_business_loss_minor?: number
          updated_at?: string
          updated_by: string
          version?: number
        }
        Update: {
          courier_return_fee_minor?: number
          created_at?: string
          created_by?: string
          customer_credit_id?: string | null
          evidence_attachment_id?: string | null
          id?: string
          inspected_at?: string | null
          journal_entry_id?: string | null
          organization_id?: string
          reason?: string
          received_at?: string | null
          requested_at?: string
          return_no?: string
          shipment_id?: string
          status?: string
          total_business_loss_minor?: number
          updated_at?: string
          updated_by?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "returns_customer_credit_fk"
            columns: ["organization_id", "customer_credit_id"]
            isOneToOne: false
            referencedRelation: "customer_credits"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "returns_evidence_attachment_id_org_fk"
            columns: ["organization_id", "evidence_attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "returns_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "returns_shipment_fk"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "returns_shipment_org_fk"
            columns: ["organization_id", "shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      shipment_items: {
        Row: {
          cod_obligation_minor: number
          created_at: string
          created_by: string
          delivered_at: string | null
          delivered_quantity: number
          delivery_fee_allocation_minor: number
          deposit_allocation_minor: number
          discount_amount_minor: number
          gross_product_amount_minor: number
          id: string
          net_product_amount_minor: number
          order_item_id: string
          organization_id: string
          quantity: number
          return_journal_entry_id: string | null
          returned_quantity: number
          revenue_journal_entry_id: string | null
          shipment_id: string
          shipping_revenue_allocation_minor: number
          unit_cost_minor: number
          unit_sale_price_minor: number
          updated_at: string
          updated_by: string
          version: number
        }
        Insert: {
          cod_obligation_minor?: number
          created_at?: string
          created_by: string
          delivered_at?: string | null
          delivered_quantity?: number
          delivery_fee_allocation_minor?: number
          deposit_allocation_minor?: number
          discount_amount_minor?: number
          gross_product_amount_minor: number
          id?: string
          net_product_amount_minor: number
          order_item_id: string
          organization_id: string
          quantity: number
          return_journal_entry_id?: string | null
          returned_quantity?: number
          revenue_journal_entry_id?: string | null
          shipment_id: string
          shipping_revenue_allocation_minor?: number
          unit_cost_minor: number
          unit_sale_price_minor: number
          updated_at?: string
          updated_by: string
          version?: number
        }
        Update: {
          cod_obligation_minor?: number
          created_at?: string
          created_by?: string
          delivered_at?: string | null
          delivered_quantity?: number
          delivery_fee_allocation_minor?: number
          deposit_allocation_minor?: number
          discount_amount_minor?: number
          gross_product_amount_minor?: number
          id?: string
          net_product_amount_minor?: number
          order_item_id?: string
          organization_id?: string
          quantity?: number
          return_journal_entry_id?: string | null
          returned_quantity?: number
          revenue_journal_entry_id?: string | null
          shipment_id?: string
          shipping_revenue_allocation_minor?: number
          unit_cost_minor?: number
          unit_sale_price_minor?: number
          updated_at?: string
          updated_by?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "shipment_items_order_item_fk"
            columns: ["order_item_id"]
            isOneToOne: false
            referencedRelation: "order_item_margin_summary"
            referencedColumns: ["order_item_id"]
          },
          {
            foreignKeyName: "shipment_items_order_item_fk"
            columns: ["order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipment_items_order_item_org_fk"
            columns: ["organization_id", "order_item_id"]
            isOneToOne: false
            referencedRelation: "order_item_margin_summary"
            referencedColumns: ["organization_id", "order_item_id"]
          },
          {
            foreignKeyName: "shipment_items_order_item_org_fk"
            columns: ["organization_id", "order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "shipment_items_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipment_items_shipment_fk"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipment_items_shipment_org_fk"
            columns: ["organization_id", "shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      shipment_status_history: {
        Row: {
          created_at: string
          created_by: string
          evidence_attachment_id: string | null
          from_status: Database["public"]["Enums"]["shipment_status"] | null
          id: string
          occurred_at: string
          organization_id: string
          reason: string | null
          shipment_id: string
          to_status: Database["public"]["Enums"]["shipment_status"]
          updated_at: string
          updated_by: string
        }
        Insert: {
          created_at?: string
          created_by: string
          evidence_attachment_id?: string | null
          from_status?: Database["public"]["Enums"]["shipment_status"] | null
          id?: string
          occurred_at: string
          organization_id: string
          reason?: string | null
          shipment_id: string
          to_status: Database["public"]["Enums"]["shipment_status"]
          updated_at?: string
          updated_by: string
        }
        Update: {
          created_at?: string
          created_by?: string
          evidence_attachment_id?: string | null
          from_status?: Database["public"]["Enums"]["shipment_status"] | null
          id?: string
          occurred_at?: string
          organization_id?: string
          reason?: string | null
          shipment_id?: string
          to_status?: Database["public"]["Enums"]["shipment_status"]
          updated_at?: string
          updated_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "shipment_status_history_evidence_attachment_id_org_fk"
            columns: ["organization_id", "evidence_attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "shipment_status_history_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipment_status_history_shipment_fk"
            columns: ["shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipment_status_history_shipment_org_fk"
            columns: ["organization_id", "shipment_id"]
            isOneToOne: false
            referencedRelation: "shipments"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      shipments: {
        Row: {
          courier_delivery_fee_minor: number
          courier_id: string
          courier_return_fee_minor: number
          created_at: string
          created_by: string
          customer_shipping_charge_minor: number
          delivered_at: string | null
          delivery_evidence_attachment_id: string | null
          delivery_journal_entry_id: string | null
          dispatch_evidence_attachment_id: string | null
          dispatched_at: string | null
          expected_cod_minor: number
          id: string
          order_id: string
          organization_id: string
          reported_collected_cod_minor: number | null
          return_evidence_attachment_id: string | null
          returned_at: string | null
          settlement_status: string
          shipment_kind: Database["public"]["Enums"]["shipment_kind"]
          shipping_zone_snapshot: string
          status: Database["public"]["Enums"]["shipment_status"]
          tracking_number: string | null
          updated_at: string
          updated_by: string
          version: number
        }
        Insert: {
          courier_delivery_fee_minor?: number
          courier_id: string
          courier_return_fee_minor?: number
          created_at?: string
          created_by: string
          customer_shipping_charge_minor?: number
          delivered_at?: string | null
          delivery_evidence_attachment_id?: string | null
          delivery_journal_entry_id?: string | null
          dispatch_evidence_attachment_id?: string | null
          dispatched_at?: string | null
          expected_cod_minor?: number
          id?: string
          order_id: string
          organization_id: string
          reported_collected_cod_minor?: number | null
          return_evidence_attachment_id?: string | null
          returned_at?: string | null
          settlement_status?: string
          shipment_kind?: Database["public"]["Enums"]["shipment_kind"]
          shipping_zone_snapshot: string
          status?: Database["public"]["Enums"]["shipment_status"]
          tracking_number?: string | null
          updated_at?: string
          updated_by: string
          version?: number
        }
        Update: {
          courier_delivery_fee_minor?: number
          courier_id?: string
          courier_return_fee_minor?: number
          created_at?: string
          created_by?: string
          customer_shipping_charge_minor?: number
          delivered_at?: string | null
          delivery_evidence_attachment_id?: string | null
          delivery_journal_entry_id?: string | null
          dispatch_evidence_attachment_id?: string | null
          dispatched_at?: string | null
          expected_cod_minor?: number
          id?: string
          order_id?: string
          organization_id?: string
          reported_collected_cod_minor?: number | null
          return_evidence_attachment_id?: string | null
          returned_at?: string | null
          settlement_status?: string
          shipment_kind?: Database["public"]["Enums"]["shipment_kind"]
          shipping_zone_snapshot?: string
          status?: Database["public"]["Enums"]["shipment_status"]
          tracking_number?: string | null
          updated_at?: string
          updated_by?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "shipments_courier_fk"
            columns: ["courier_id"]
            isOneToOne: false
            referencedRelation: "couriers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipments_courier_org_fk"
            columns: ["organization_id", "courier_id"]
            isOneToOne: false
            referencedRelation: "couriers"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "shipments_delivery_evidence_attachment_id_org_fk"
            columns: ["organization_id", "delivery_evidence_attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "shipments_dispatch_evidence_attachment_id_org_fk"
            columns: ["organization_id", "dispatch_evidence_attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "shipments_order_fk"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "order_financial_summary"
            referencedColumns: ["order_id"]
          },
          {
            foreignKeyName: "shipments_order_fk"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipments_order_org_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "order_financial_summary"
            referencedColumns: ["organization_id", "order_id"]
          },
          {
            foreignKeyName: "shipments_order_org_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "shipments_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipments_return_evidence_attachment_id_org_fk"
            columns: ["organization_id", "return_evidence_attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      shipping_rate_rules: {
        Row: {
          cod_fee_bps: number
          cod_fixed_fee_minor: number
          courier_id: string
          created_at: string
          created_by: string | null
          currency_code: string
          delivery_fee_minor: number
          effective_from: string
          effective_to: string | null
          id: string
          is_active: boolean
          notes: string | null
          organization_id: string
          priority: number
          return_fee_minor: number
          service_type: string
          shipping_zone_id: string
          updated_at: string
        }
        Insert: {
          cod_fee_bps?: number
          cod_fixed_fee_minor?: number
          courier_id: string
          created_at?: string
          created_by?: string | null
          currency_code?: string
          delivery_fee_minor: number
          effective_from: string
          effective_to?: string | null
          id?: string
          is_active?: boolean
          notes?: string | null
          organization_id: string
          priority?: number
          return_fee_minor: number
          service_type?: string
          shipping_zone_id: string
          updated_at?: string
        }
        Update: {
          cod_fee_bps?: number
          cod_fixed_fee_minor?: number
          courier_id?: string
          created_at?: string
          created_by?: string | null
          currency_code?: string
          delivery_fee_minor?: number
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_active?: boolean
          notes?: string | null
          organization_id?: string
          priority?: number
          return_fee_minor?: number
          service_type?: string
          shipping_zone_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "shipping_rate_rules_courier_org_fk"
            columns: ["organization_id", "courier_id"]
            isOneToOne: false
            referencedRelation: "couriers"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "shipping_rate_rules_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipping_rate_rules_zone_org_fk"
            columns: ["organization_id", "shipping_zone_id"]
            isOneToOne: false
            referencedRelation: "shipping_zones"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      shipping_settings: {
        Row: {
          created_at: string
          id: string
          key: string
          organization_id: string
          updated_at: string
          value: Json
        }
        Insert: {
          created_at?: string
          id?: string
          key: string
          organization_id?: string
          updated_at?: string
          value: Json
        }
        Update: {
          created_at?: string
          id?: string
          key?: string
          organization_id?: string
          updated_at?: string
          value?: Json
        }
        Relationships: [
          {
            foreignKeyName: "shipping_settings_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      shipping_zones: {
        Row: {
          archived_at: string | null
          created_at: string
          created_by: string | null
          display_name: string
          governorates: string[]
          id: string
          is_active: boolean
          organization_id: string
          updated_at: string
          zone_code: string
        }
        Insert: {
          archived_at?: string | null
          created_at?: string
          created_by?: string | null
          display_name: string
          governorates?: string[]
          id?: string
          is_active?: boolean
          organization_id: string
          updated_at?: string
          zone_code: string
        }
        Update: {
          archived_at?: string | null
          created_at?: string
          created_by?: string | null
          display_name?: string
          governorates?: string[]
          id?: string
          is_active?: boolean
          organization_id?: string
          updated_at?: string
          zone_code?: string
        }
        Relationships: [
          {
            foreignKeyName: "shipping_zones_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      supplier_invoice_items: {
        Row: {
          created_at: string
          created_by: string
          description: string
          grni_accrual_id: string | null
          id: string
          invoiced_quantity: number
          invoiced_unit_cost_minor: number
          line_amount_minor: number
          matched_grni_minor: number
          organization_id: string
          print_batch_item_id: string
          supplier_invoice_id: string
          updated_at: string
          updated_by: string
          variance_minor: number
        }
        Insert: {
          created_at?: string
          created_by: string
          description: string
          grni_accrual_id?: string | null
          id?: string
          invoiced_quantity: number
          invoiced_unit_cost_minor: number
          line_amount_minor: number
          matched_grni_minor?: number
          organization_id: string
          print_batch_item_id: string
          supplier_invoice_id: string
          updated_at?: string
          updated_by: string
          variance_minor?: number
        }
        Update: {
          created_at?: string
          created_by?: string
          description?: string
          grni_accrual_id?: string | null
          id?: string
          invoiced_quantity?: number
          invoiced_unit_cost_minor?: number
          line_amount_minor?: number
          matched_grni_minor?: number
          organization_id?: string
          print_batch_item_id?: string
          supplier_invoice_id?: string
          updated_at?: string
          updated_by?: string
          variance_minor?: number
        }
        Relationships: [
          {
            foreignKeyName: "supplier_invoice_items_batch_item_fk"
            columns: ["print_batch_item_id"]
            isOneToOne: false
            referencedRelation: "print_batch_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoice_items_batch_item_org_fk"
            columns: ["organization_id", "print_batch_item_id"]
            isOneToOne: false
            referencedRelation: "print_batch_items"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "supplier_invoice_items_grni_fk"
            columns: ["grni_accrual_id"]
            isOneToOne: false
            referencedRelation: "grni_accruals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoice_items_grni_org_fk"
            columns: ["organization_id", "grni_accrual_id"]
            isOneToOne: false
            referencedRelation: "grni_accruals"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "supplier_invoice_items_invoice_fk"
            columns: ["supplier_invoice_id"]
            isOneToOne: false
            referencedRelation: "supplier_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoice_items_invoice_org_fk"
            columns: ["organization_id", "supplier_invoice_id"]
            isOneToOne: false
            referencedRelation: "supplier_invoices"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "supplier_invoice_items_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      supplier_invoices: {
        Row: {
          approval_request_id: string | null
          approved_variance_minor: number
          cancellation_reason: string | null
          created_at: string
          created_by: string
          credit_minor: number
          currency_code: string
          due_date: string | null
          id: string
          invoice_date: string
          invoice_no: string
          journal_entry_id: string | null
          organization_id: string
          posted_at: string | null
          posted_by: string | null
          print_batch_id: string | null
          status: Database["public"]["Enums"]["supplier_invoice_status"]
          subtotal_minor: number
          supplier_id: string
          tax_minor: number
          total_minor: number
          updated_at: string
          updated_by: string
          version: number
        }
        Insert: {
          approval_request_id?: string | null
          approved_variance_minor?: number
          cancellation_reason?: string | null
          created_at?: string
          created_by: string
          credit_minor?: number
          currency_code?: string
          due_date?: string | null
          id?: string
          invoice_date: string
          invoice_no: string
          journal_entry_id?: string | null
          organization_id: string
          posted_at?: string | null
          posted_by?: string | null
          print_batch_id?: string | null
          status?: Database["public"]["Enums"]["supplier_invoice_status"]
          subtotal_minor: number
          supplier_id: string
          tax_minor?: number
          total_minor: number
          updated_at?: string
          updated_by: string
          version?: number
        }
        Update: {
          approval_request_id?: string | null
          approved_variance_minor?: number
          cancellation_reason?: string | null
          created_at?: string
          created_by?: string
          credit_minor?: number
          currency_code?: string
          due_date?: string | null
          id?: string
          invoice_date?: string
          invoice_no?: string
          journal_entry_id?: string | null
          organization_id?: string
          posted_at?: string | null
          posted_by?: string | null
          print_batch_id?: string | null
          status?: Database["public"]["Enums"]["supplier_invoice_status"]
          subtotal_minor?: number
          supplier_id?: string
          tax_minor?: number
          total_minor?: number
          updated_at?: string
          updated_by?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "supplier_invoices_approval_fk"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoices_approval_org_fk"
            columns: ["organization_id", "approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "supplier_invoices_batch_fk"
            columns: ["print_batch_id"]
            isOneToOne: false
            referencedRelation: "print_batches"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoices_batch_org_fk"
            columns: ["organization_id", "print_batch_id"]
            isOneToOne: false
            referencedRelation: "print_batches"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "supplier_invoices_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoices_supplier_fk"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoices_supplier_org_fk"
            columns: ["organization_id", "supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      supplier_payments: {
        Row: {
          amount_minor: number
          created_at: string
          created_by: string
          evidence_attachment_id: string | null
          id: string
          journal_entry_id: string | null
          organization_id: string
          payment_date: string
          provider_reference: string | null
          reverses_supplier_payment_id: string | null
          supplier_invoice_id: string
          updated_at: string
          updated_by: string
          wallet_id: string
        }
        Insert: {
          amount_minor: number
          created_at?: string
          created_by: string
          evidence_attachment_id?: string | null
          id?: string
          journal_entry_id?: string | null
          organization_id: string
          payment_date: string
          provider_reference?: string | null
          reverses_supplier_payment_id?: string | null
          supplier_invoice_id: string
          updated_at?: string
          updated_by: string
          wallet_id: string
        }
        Update: {
          amount_minor?: number
          created_at?: string
          created_by?: string
          evidence_attachment_id?: string | null
          id?: string
          journal_entry_id?: string | null
          organization_id?: string
          payment_date?: string
          provider_reference?: string | null
          reverses_supplier_payment_id?: string | null
          supplier_invoice_id?: string
          updated_at?: string
          updated_by?: string
          wallet_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "supplier_payments_evidence_attachment_id_org_fk"
            columns: ["organization_id", "evidence_attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "supplier_payments_invoice_fk"
            columns: ["supplier_invoice_id"]
            isOneToOne: false
            referencedRelation: "supplier_invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_payments_invoice_org_fk"
            columns: ["organization_id", "supplier_invoice_id"]
            isOneToOne: false
            referencedRelation: "supplier_invoices"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "supplier_payments_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_payments_reversal_fk"
            columns: ["reverses_supplier_payment_id"]
            isOneToOne: false
            referencedRelation: "supplier_payments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_payments_reversal_org_fk"
            columns: ["organization_id", "reverses_supplier_payment_id"]
            isOneToOne: false
            referencedRelation: "supplier_payments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "supplier_payments_wallet_fk"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["wallet_id"]
          },
          {
            foreignKeyName: "supplier_payments_wallet_fk"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_payments_wallet_org_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["organization_id", "wallet_id"]
          },
          {
            foreignKeyName: "supplier_payments_wallet_org_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      supplier_price_rules: {
        Row: {
          case_and_print_price_minor: number | null
          created_at: string
          created_by: string | null
          currency_code: string
          effective_from: string
          effective_to: string | null
          id: string
          is_active: boolean
          notes: string | null
          organization_id: string
          phone_model_id: string | null
          printing_only_price_minor: number | null
          priority: number
          product_category_id: string | null
          product_id: string | null
          supplier_id: string
          supply_method_code: string
          updated_at: string
        }
        Insert: {
          case_and_print_price_minor?: number | null
          created_at?: string
          created_by?: string | null
          currency_code?: string
          effective_from: string
          effective_to?: string | null
          id?: string
          is_active?: boolean
          notes?: string | null
          organization_id: string
          phone_model_id?: string | null
          printing_only_price_minor?: number | null
          priority?: number
          product_category_id?: string | null
          product_id?: string | null
          supplier_id: string
          supply_method_code: string
          updated_at?: string
        }
        Update: {
          case_and_print_price_minor?: number | null
          created_at?: string
          created_by?: string | null
          currency_code?: string
          effective_from?: string
          effective_to?: string | null
          id?: string
          is_active?: boolean
          notes?: string | null
          organization_id?: string
          phone_model_id?: string | null
          printing_only_price_minor?: number | null
          priority?: number
          product_category_id?: string | null
          product_id?: string | null
          supplier_id?: string
          supply_method_code?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "supplier_price_rules_category_org_fk"
            columns: ["organization_id", "product_category_id"]
            isOneToOne: false
            referencedRelation: "product_categories"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "supplier_price_rules_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_price_rules_phone_model_org_fk"
            columns: ["organization_id", "phone_model_id"]
            isOneToOne: false
            referencedRelation: "phone_models"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "supplier_price_rules_product_org_fk"
            columns: ["organization_id", "product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "supplier_price_rules_supplier_org_fk"
            columns: ["organization_id", "supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      suppliers: {
        Row: {
          archived_at: string | null
          contact_name: string | null
          created_at: string
          created_by: string | null
          display_name: string
          id: string
          is_active: boolean
          legal_name: string | null
          notes: string | null
          organization_id: string
          payment_terms_days: number
          phone_normalized: string | null
          phone_original: string | null
          supplier_code: string
          updated_at: string
        }
        Insert: {
          archived_at?: string | null
          contact_name?: string | null
          created_at?: string
          created_by?: string | null
          display_name: string
          id?: string
          is_active?: boolean
          legal_name?: string | null
          notes?: string | null
          organization_id: string
          payment_terms_days?: number
          phone_normalized?: string | null
          phone_original?: string | null
          supplier_code: string
          updated_at?: string
        }
        Update: {
          archived_at?: string | null
          contact_name?: string | null
          created_at?: string
          created_by?: string | null
          display_name?: string
          id?: string
          is_active?: boolean
          legal_name?: string | null
          notes?: string | null
          organization_id?: string
          payment_terms_days?: number
          phone_normalized?: string | null
          phone_original?: string | null
          supplier_code?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "suppliers_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      wallet_reconciliation_items: {
        Row: {
          book_balance_after_minor: number | null
          created_at: string
          description: string
          id: string
          movement_amount_minor: number
          movement_type: string
          occurred_at: string
          organization_id: string
          sequence_number: number
          source_id: string
          source_type: string
          updated_at: string
          wallet_id: string
          wallet_reconciliation_id: string
        }
        Insert: {
          book_balance_after_minor?: number | null
          created_at?: string
          description: string
          id?: string
          movement_amount_minor: number
          movement_type: string
          occurred_at: string
          organization_id: string
          sequence_number: number
          source_id: string
          source_type: string
          updated_at?: string
          wallet_id: string
          wallet_reconciliation_id: string
        }
        Update: {
          book_balance_after_minor?: number | null
          created_at?: string
          description?: string
          id?: string
          movement_amount_minor?: number
          movement_type?: string
          occurred_at?: string
          organization_id?: string
          sequence_number?: number
          source_id?: string
          source_type?: string
          updated_at?: string
          wallet_id?: string
          wallet_reconciliation_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "wallet_reconciliation_items_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_reconciliation_items_reconciliation_fk"
            columns: [
              "organization_id",
              "wallet_reconciliation_id",
              "wallet_id",
            ]
            isOneToOne: false
            referencedRelation: "wallet_reconciliation_summary"
            referencedColumns: [
              "organization_id",
              "reconciliation_id",
              "wallet_id",
            ]
          },
          {
            foreignKeyName: "wallet_reconciliation_items_reconciliation_fk"
            columns: [
              "organization_id",
              "wallet_reconciliation_id",
              "wallet_id",
            ]
            isOneToOne: false
            referencedRelation: "wallet_reconciliations"
            referencedColumns: ["organization_id", "id", "wallet_id"]
          },
          {
            foreignKeyName: "wallet_reconciliation_items_wallet_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["organization_id", "wallet_id"]
          },
          {
            foreignKeyName: "wallet_reconciliation_items_wallet_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      wallet_reconciliations: {
        Row: {
          actual_closing_balance_minor: number
          adjustment_reference_id: string | null
          adjustment_reference_type: string | null
          approval_request_id: string | null
          correlation_id: string
          created_at: string
          currency: string
          difference_explanation: string | null
          difference_minor: number
          evidence_attachment_id: string | null
          expected_closing_balance_minor: number
          finalized_at: string | null
          id: string
          opening_book_balance_minor: number
          organization_id: string
          period_ended_at: string
          period_started_at: string
          prepared_at: string
          prepared_by: string
          reconciliation_date: string
          reviewed_at: string | null
          reviewed_by: string | null
          status: string
          system_movements_minor: number
          updated_at: string
          wallet_id: string
        }
        Insert: {
          actual_closing_balance_minor: number
          adjustment_reference_id?: string | null
          adjustment_reference_type?: string | null
          approval_request_id?: string | null
          correlation_id: string
          created_at?: string
          currency?: string
          difference_explanation?: string | null
          difference_minor: number
          evidence_attachment_id?: string | null
          expected_closing_balance_minor: number
          finalized_at?: string | null
          id?: string
          opening_book_balance_minor: number
          organization_id: string
          period_ended_at: string
          period_started_at: string
          prepared_at?: string
          prepared_by: string
          reconciliation_date: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          system_movements_minor: number
          updated_at?: string
          wallet_id: string
        }
        Update: {
          actual_closing_balance_minor?: number
          adjustment_reference_id?: string | null
          adjustment_reference_type?: string | null
          approval_request_id?: string | null
          correlation_id?: string
          created_at?: string
          currency?: string
          difference_explanation?: string | null
          difference_minor?: number
          evidence_attachment_id?: string | null
          expected_closing_balance_minor?: number
          finalized_at?: string | null
          id?: string
          opening_book_balance_minor?: number
          organization_id?: string
          period_ended_at?: string
          period_started_at?: string
          prepared_at?: string
          prepared_by?: string
          reconciliation_date?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          system_movements_minor?: number
          updated_at?: string
          wallet_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "wallet_reconciliations_approval_request_id_fkey"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_reconciliations_evidence_attachment_id_org_fk"
            columns: ["organization_id", "evidence_attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "wallet_reconciliations_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_reconciliations_prepared_by_fkey"
            columns: ["prepared_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_reconciliations_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_reconciliations_wallet_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["organization_id", "wallet_id"]
          },
          {
            foreignKeyName: "wallet_reconciliations_wallet_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      wallet_transfers: {
        Row: {
          amount_minor: number
          approval_request_id: string | null
          approved_at: string | null
          approved_by: string | null
          cancelled_at: string | null
          correlation_id: string
          created_at: string
          currency: string
          destination_wallet_id: string
          evidence_attachment_id: string | null
          executed_at: string | null
          executed_by: string | null
          fee_minor: number
          fee_reference: string | null
          id: string
          idempotency_key: string
          organization_id: string
          reason: string
          request_fingerprint: string
          requested_at: string
          requested_by: string
          reversed_at: string | null
          source_wallet_id: string
          status: string
          transfer_reference: string | null
          updated_at: string
        }
        Insert: {
          amount_minor: number
          approval_request_id?: string | null
          approved_at?: string | null
          approved_by?: string | null
          cancelled_at?: string | null
          correlation_id: string
          created_at?: string
          currency?: string
          destination_wallet_id: string
          evidence_attachment_id?: string | null
          executed_at?: string | null
          executed_by?: string | null
          fee_minor?: number
          fee_reference?: string | null
          id?: string
          idempotency_key: string
          organization_id: string
          reason: string
          request_fingerprint: string
          requested_at?: string
          requested_by: string
          reversed_at?: string | null
          source_wallet_id: string
          status?: string
          transfer_reference?: string | null
          updated_at?: string
        }
        Update: {
          amount_minor?: number
          approval_request_id?: string | null
          approved_at?: string | null
          approved_by?: string | null
          cancelled_at?: string | null
          correlation_id?: string
          created_at?: string
          currency?: string
          destination_wallet_id?: string
          evidence_attachment_id?: string | null
          executed_at?: string | null
          executed_by?: string | null
          fee_minor?: number
          fee_reference?: string | null
          id?: string
          idempotency_key?: string
          organization_id?: string
          reason?: string
          request_fingerprint?: string
          requested_at?: string
          requested_by?: string
          reversed_at?: string | null
          source_wallet_id?: string
          status?: string
          transfer_reference?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "wallet_transfers_approval_request_id_fkey"
            columns: ["approval_request_id"]
            isOneToOne: false
            referencedRelation: "approval_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_transfers_approved_by_fkey"
            columns: ["approved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_transfers_destination_wallet_fk"
            columns: ["organization_id", "destination_wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["organization_id", "wallet_id"]
          },
          {
            foreignKeyName: "wallet_transfers_destination_wallet_fk"
            columns: ["organization_id", "destination_wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "wallet_transfers_evidence_attachment_id_org_fk"
            columns: ["organization_id", "evidence_attachment_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "wallet_transfers_executed_by_fkey"
            columns: ["executed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_transfers_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_transfers_requested_by_fkey"
            columns: ["requested_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_transfers_source_wallet_fk"
            columns: ["organization_id", "source_wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["organization_id", "wallet_id"]
          },
          {
            foreignKeyName: "wallet_transfers_source_wallet_fk"
            columns: ["organization_id", "source_wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      wallets: {
        Row: {
          closed_at: string | null
          code: string
          created_at: string
          created_by: string | null
          currency: string
          economic_owner_name: string
          external_identifier_last4: string | null
          id: string
          is_active: boolean
          name: string
          notes: string | null
          opened_at: string | null
          organization_id: string
          provider: string
          registered_owner_name: string
          registered_owner_profile_id: string | null
          updated_at: string
          wallet_type: string
        }
        Insert: {
          closed_at?: string | null
          code: string
          created_at?: string
          created_by?: string | null
          currency?: string
          economic_owner_name?: string
          external_identifier_last4?: string | null
          id?: string
          is_active?: boolean
          name: string
          notes?: string | null
          opened_at?: string | null
          organization_id: string
          provider: string
          registered_owner_name: string
          registered_owner_profile_id?: string | null
          updated_at?: string
          wallet_type: string
        }
        Update: {
          closed_at?: string | null
          code?: string
          created_at?: string
          created_by?: string | null
          currency?: string
          economic_owner_name?: string
          external_identifier_last4?: string | null
          id?: string
          is_active?: boolean
          name?: string
          notes?: string | null
          opened_at?: string | null
          organization_id?: string
          provider?: string
          registered_owner_name?: string
          registered_owner_profile_id?: string | null
          updated_at?: string
          wallet_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "wallets_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallets_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallets_registered_owner_profile_id_fkey"
            columns: ["registered_owner_profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      approval_queue_summary: {
        Row: {
          oldest_requested_at: string | null
          organization_id: string | null
          request_count: number | null
          request_type: string | null
          requested_amount_minor: number | null
          status: Database["public"]["Enums"]["approval_status"] | null
        }
        Relationships: [
          {
            foreignKeyName: "approval_requests_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      courier_receivable_summary: {
        Row: {
          accrued_courier_fees_minor: number | null
          contractual_cod_minor: number | null
          courier_id: string | null
          courier_reported_cod_minor: number | null
          organization_id: string | null
          unsettled_shipments: number | null
        }
        Relationships: [
          {
            foreignKeyName: "shipments_courier_fk"
            columns: ["courier_id"]
            isOneToOne: false
            referencedRelation: "couriers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "shipments_courier_org_fk"
            columns: ["organization_id", "courier_id"]
            isOneToOne: false
            referencedRelation: "couriers"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "shipments_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      courier_settlement_summary: {
        Row: {
          actual_transfer_minor: number | null
          contractual_cod_minor: number | null
          courier_id: string | null
          delivery_fees_minor: number | null
          difference_classification: string | null
          difference_minor: number | null
          expected_net_settlement_minor: number | null
          is_off_cycle: boolean | null
          organization_id: string | null
          period_end: string | null
          period_start: string | null
          return_fees_minor: number | null
          settlement_id: string | null
          settlement_no: string | null
          status: Database["public"]["Enums"]["settlement_status"] | null
        }
        Insert: {
          actual_transfer_minor?: number | null
          contractual_cod_minor?: number | null
          courier_id?: string | null
          delivery_fees_minor?: number | null
          difference_classification?: string | null
          difference_minor?: number | null
          expected_net_settlement_minor?: number | null
          is_off_cycle?: boolean | null
          organization_id?: string | null
          period_end?: string | null
          period_start?: string | null
          return_fees_minor?: number | null
          settlement_id?: string | null
          settlement_no?: string | null
          status?: Database["public"]["Enums"]["settlement_status"] | null
        }
        Update: {
          actual_transfer_minor?: number | null
          contractual_cod_minor?: number | null
          courier_id?: string | null
          delivery_fees_minor?: number | null
          difference_classification?: string | null
          difference_minor?: number | null
          expected_net_settlement_minor?: number | null
          is_off_cycle?: boolean | null
          organization_id?: string | null
          period_end?: string | null
          period_start?: string | null
          return_fees_minor?: number | null
          settlement_id?: string | null
          settlement_no?: string | null
          status?: Database["public"]["Enums"]["settlement_status"] | null
        }
        Relationships: [
          {
            foreignKeyName: "courier_settlements_courier_fk"
            columns: ["courier_id"]
            isOneToOne: false
            referencedRelation: "couriers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "courier_settlements_courier_org_fk"
            columns: ["organization_id", "courier_id"]
            isOneToOne: false
            referencedRelation: "couriers"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "courier_settlements_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      customer_deposit_summary: {
        Row: {
          available_credit_minor: number | null
          customer_id: string | null
          open_credit_lots: number | null
          organization_id: string | null
          original_credit_minor: number | null
        }
        Relationships: [
          {
            foreignKeyName: "customer_credits_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "customer_credits_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      employee_bonus_summary: {
        Row: {
          approved_review_count: number | null
          employee_id: string | null
          latest_review_period_end: string | null
          organization_id: string | null
          review_count: number | null
        }
        Relationships: [
          {
            foreignKeyName: "employee_performance_reviews_employee_fk"
            columns: ["employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "employee_performance_reviews_employee_org_fk"
            columns: ["organization_id", "employee_id"]
            isOneToOne: false
            referencedRelation: "employees"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "employee_performance_reviews_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      inventory_balance_by_location: {
        Row: {
          inventory_cost_minor: number | null
          location_id: string | null
          organization_id: string | null
          product_variant_id: string | null
          quantity_on_hand: number | null
        }
        Relationships: []
      }
      inventory_negative_balance_alerts: {
        Row: {
          inventory_cost_minor: number | null
          location_id: string | null
          organization_id: string | null
          product_variant_id: string | null
          quantity_on_hand: number | null
        }
        Relationships: []
      }
      order_financial_summary: {
        Row: {
          actual_cost_minor: number | null
          actual_margin_minor: number | null
          balance_due_minor: number | null
          confirmed_at: string | null
          confirmed_payment_minor: number | null
          customer_id: string | null
          delivered_at: string | null
          discount_total_minor: number | null
          expected_cost_minor: number | null
          expected_margin_minor: number | null
          financially_settled_at: string | null
          order_id: string | null
          order_number: string | null
          order_total_minor: number | null
          organization_id: string | null
          payment_status: Database["public"]["Enums"]["payment_status"] | null
          products_subtotal_minor: number | null
          required_deposit_minor: number | null
          shipping_charge_minor: number | null
          status: Database["public"]["Enums"]["order_status"] | null
        }
        Insert: {
          actual_cost_minor?: number | null
          actual_margin_minor?: number | null
          balance_due_minor?: number | null
          confirmed_at?: string | null
          confirmed_payment_minor?: number | null
          customer_id?: string | null
          delivered_at?: string | null
          discount_total_minor?: number | null
          expected_cost_minor?: number | null
          expected_margin_minor?: number | null
          financially_settled_at?: string | null
          order_id?: string | null
          order_number?: string | null
          order_total_minor?: number | null
          organization_id?: string | null
          payment_status?: Database["public"]["Enums"]["payment_status"] | null
          products_subtotal_minor?: number | null
          required_deposit_minor?: number | null
          shipping_charge_minor?: number | null
          status?: Database["public"]["Enums"]["order_status"] | null
        }
        Update: {
          actual_cost_minor?: number | null
          actual_margin_minor?: number | null
          balance_due_minor?: number | null
          confirmed_at?: string | null
          confirmed_payment_minor?: number | null
          customer_id?: string | null
          delivered_at?: string | null
          discount_total_minor?: number | null
          expected_cost_minor?: number | null
          expected_margin_minor?: number | null
          financially_settled_at?: string | null
          order_id?: string | null
          order_number?: string | null
          order_total_minor?: number | null
          organization_id?: string | null
          payment_status?: Database["public"]["Enums"]["payment_status"] | null
          products_subtotal_minor?: number | null
          required_deposit_minor?: number | null
          shipping_charge_minor?: number | null
          status?: Database["public"]["Enums"]["order_status"] | null
        }
        Relationships: [
          {
            foreignKeyName: "orders_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      order_item_margin_summary: {
        Row: {
          actual_cost_minor: number | null
          actual_margin_minor: number | null
          costing_status: string | null
          expected_cost_minor: number | null
          fulfillment_status:
            | Database["public"]["Enums"]["fulfillment_status"]
            | null
          item_type: Database["public"]["Enums"]["item_type"] | null
          line_discount_minor: number | null
          line_gross_minor: number | null
          line_number: number | null
          line_revenue_minor: number | null
          order_id: string | null
          order_item_id: string | null
          organization_id: string | null
          quantity: number | null
        }
        Insert: {
          actual_cost_minor?: number | null
          actual_margin_minor?: never
          costing_status?: string | null
          expected_cost_minor?: never
          fulfillment_status?:
            | Database["public"]["Enums"]["fulfillment_status"]
            | null
          item_type?: Database["public"]["Enums"]["item_type"] | null
          line_discount_minor?: number | null
          line_gross_minor?: number | null
          line_number?: number | null
          line_revenue_minor?: number | null
          order_id?: string | null
          order_item_id?: string | null
          organization_id?: string | null
          quantity?: number | null
        }
        Update: {
          actual_cost_minor?: number | null
          actual_margin_minor?: never
          costing_status?: string | null
          expected_cost_minor?: never
          fulfillment_status?:
            | Database["public"]["Enums"]["fulfillment_status"]
            | null
          item_type?: Database["public"]["Enums"]["item_type"] | null
          line_discount_minor?: number | null
          line_gross_minor?: number | null
          line_number?: number | null
          line_revenue_minor?: number | null
          order_id?: string | null
          order_item_id?: string | null
          organization_id?: string | null
          quantity?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "order_items_order_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "order_financial_summary"
            referencedColumns: ["organization_id", "order_id"]
          },
          {
            foreignKeyName: "order_items_order_fk"
            columns: ["organization_id", "order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "order_items_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      partner_account_summary: {
        Row: {
          allocated_profit_minor: number | null
          capital_and_current_minor: number | null
          executed_withdrawals_minor: number | null
          full_name: string | null
          organization_id: string | null
          partner_code: string | null
          partner_id: string | null
        }
        Insert: {
          allocated_profit_minor?: never
          capital_and_current_minor?: never
          executed_withdrawals_minor?: never
          full_name?: string | null
          organization_id?: string | null
          partner_code?: string | null
          partner_id?: string | null
        }
        Update: {
          allocated_profit_minor?: never
          capital_and_current_minor?: never
          executed_withdrawals_minor?: never
          full_name?: string | null
          organization_id?: string | null
          partner_code?: string | null
          partner_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "partners_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      payroll_status_summary: {
        Row: {
          employee_count: number | null
          net_payroll_minor: number | null
          organization_id: string | null
          outstanding_minor: number | null
          paid_minor: number | null
          payroll_period_id: string | null
          status: Database["public"]["Enums"]["payroll_status"] | null
        }
        Relationships: [
          {
            foreignKeyName: "payroll_entries_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payroll_entries_period_fk"
            columns: ["payroll_period_id"]
            isOneToOne: false
            referencedRelation: "payroll_periods"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payroll_entries_period_org_fk"
            columns: ["organization_id", "payroll_period_id"]
            isOneToOne: false
            referencedRelation: "payroll_periods"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      supplier_payable_summary: {
        Row: {
          invoiced_minor: number | null
          open_payable_minor: number | null
          organization_id: string | null
          paid_minor: number | null
          supplier_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "supplier_invoices_organization_fk"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoices_supplier_fk"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoices_supplier_org_fk"
            columns: ["organization_id", "supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      unposted_financial_events: {
        Row: {
          event_id: string | null
          event_type: string | null
          occurred_at: string | null
          organization_id: string | null
          subject_id: string | null
        }
        Relationships: []
      }
      wallet_balance_summary: {
        Row: {
          code: string | null
          confirmed_customer_receipts_minor: number | null
          currency: string | null
          is_active: boolean | null
          last_confirmed_receipt_at: string | null
          name: string | null
          organization_id: string | null
          provider: string | null
          wallet_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "wallets_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      wallet_reconciliation_summary: {
        Row: {
          actual_closing_balance_minor: number | null
          difference_minor: number | null
          expected_closing_balance_minor: number | null
          finalized_at: string | null
          opening_book_balance_minor: number | null
          organization_id: string | null
          period_ended_at: string | null
          period_started_at: string | null
          reconciliation_date: string | null
          reconciliation_id: string | null
          status: string | null
          system_movements_minor: number | null
          wallet_id: string | null
        }
        Insert: {
          actual_closing_balance_minor?: number | null
          difference_minor?: number | null
          expected_closing_balance_minor?: number | null
          finalized_at?: string | null
          opening_book_balance_minor?: number | null
          organization_id?: string | null
          period_ended_at?: string | null
          period_started_at?: string | null
          reconciliation_date?: string | null
          reconciliation_id?: string | null
          status?: string | null
          system_movements_minor?: number | null
          wallet_id?: string | null
        }
        Update: {
          actual_closing_balance_minor?: number | null
          difference_minor?: number | null
          expected_closing_balance_minor?: number | null
          finalized_at?: string | null
          opening_book_balance_minor?: number | null
          organization_id?: string | null
          period_ended_at?: string | null
          period_started_at?: string | null
          reconciliation_date?: string | null
          reconciliation_id?: string | null
          status?: string | null
          system_movements_minor?: number | null
          wallet_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "wallet_reconciliations_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_reconciliations_wallet_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallet_balance_summary"
            referencedColumns: ["organization_id", "wallet_id"]
          },
          {
            foreignKeyName: "wallet_reconciliations_wallet_fk"
            columns: ["organization_id", "wallet_id"]
            isOneToOne: false
            referencedRelation: "wallets"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      accounting_period_status:
        | "open"
        | "closing"
        | "closed"
        | "reopened_exceptionally"
      approval_action_type: "approve" | "reject" | "cancel"
      approval_status:
        | "draft"
        | "submitted"
        | "approved"
        | "rejected"
        | "expired"
        | "cancelled"
        | "consumed"
      bonus_review_status:
        | "draft"
        | "calculated"
        | "reviewed"
        | "approved"
        | "rejected"
        | "superseded"
      command_status: "in_progress" | "succeeded" | "failed_terminal"
      courier_settlement_line_type:
        | "contractual_cod_receivable"
        | "prepaid_delivery_payable"
        | "delivery_fee_payable"
        | "return_fee_payable"
        | "approved_deduction"
        | "adjustment"
        | "prior_carry_forward"
        | "remittance"
        | "claim"
        | "dispute"
      employee_advance_status:
        | "draft"
        | "approved"
        | "paid"
        | "partially_recovered"
        | "recovered"
        | "cancelled"
        | "reversed"
      employee_kind:
        | "moderator"
        | "operations"
        | "finance"
        | "management"
        | "other"
      employee_status:
        | "draft"
        | "active"
        | "on_leave"
        | "terminated"
        | "inactive"
      expense_status:
        | "draft"
        | "submitted"
        | "approved"
        | "partially_paid"
        | "paid"
        | "cancelled"
        | "reversed"
      fulfillment_status:
        | "draft"
        | "planned"
        | "queued"
        | "in_production"
        | "partially_fulfilled"
        | "fulfilled"
        | "partially_returned"
        | "returned"
        | "cancelled"
        | "problem"
      inventory_movement_type:
        | "purchase_receipt"
        | "transfer"
        | "reservation"
        | "reservation_release"
        | "production_issue"
        | "production_receipt"
        | "sale"
        | "customer_return"
        | "damage"
        | "loss"
        | "adjustment"
        | "gift_consumption"
        | "packaging_consumption"
      item_type:
        | "paid_product"
        | "accessory"
        | "gift"
        | "design_service"
        | "replacement"
        | "free_reprint"
        | "paid_reprint"
        | "packaging"
      journal_status: "draft" | "posted" | "reversed"
      order_status:
        | "new"
        | "waiting_customer"
        | "waiting_deposit"
        | "confirmed"
        | "in_print_batch"
        | "printing"
        | "received_from_printer"
        | "quality_check"
        | "ready_to_ship"
        | "shipped"
        | "partially_delivered"
        | "delivered"
        | "partially_returned"
        | "returned"
        | "cancelled"
        | "problem"
        | "financially_settled"
      partner_loan_status:
        | "draft"
        | "active"
        | "partially_repaid"
        | "repaid"
        | "cancelled"
        | "reversed"
      partner_transaction_type:
        | "capital_contribution"
        | "capital_return"
        | "current_account_credit"
        | "current_account_debit"
      partner_withdrawal_type:
        | "available_profit_draw"
        | "future_profit_advance"
        | "expense_reimbursement"
        | "partner_loan_repayment"
        | "other_approved"
      payment_review_status:
        | "pending_review"
        | "confirmed"
        | "rejected"
        | "reversed"
      payment_status:
        | "no_payment"
        | "partial"
        | "required_deposit_paid"
        | "fully_prepaid"
        | "cash_on_delivery"
        | "overpaid"
        | "refund_due"
        | "partially_refunded"
        | "fully_refunded"
      payroll_status:
        | "draft"
        | "calculated"
        | "approved"
        | "partially_paid"
        | "paid"
        | "overdue"
        | "cancelled"
        | "reversed"
      print_batch_status:
        | "draft"
        | "sent"
        | "acknowledged"
        | "in_production"
        | "partially_received"
        | "fully_received"
        | "quality_check"
        | "issue_detected"
        | "ready_for_invoice"
        | "partially_paid"
        | "fully_paid"
        | "closed"
        | "cancelled"
      production_attempt_status:
        | "planned"
        | "queued"
        | "sent"
        | "partially_received"
        | "received"
        | "qc_complete"
        | "reprint_planned"
        | "closed"
        | "cancelled"
      profit_distribution_status:
        | "draft"
        | "submitted"
        | "approved"
        | "posted"
        | "cancelled"
        | "reversed"
      qc_status: "pending" | "accepted" | "partially_accepted" | "rejected"
      return_disposition:
        | "pending_inspection"
        | "resellable"
        | "damaged"
        | "reprint"
        | "discarded"
        | "not_returned"
      settlement_status:
        | "draft"
        | "prepared"
        | "reviewed"
        | "approved"
        | "posted"
        | "disputed"
        | "cancelled"
      shipment_kind: "primary" | "split" | "replacement" | "return_to_customer"
      shipment_status:
        | "draft"
        | "dispatched"
        | "partially_delivered"
        | "delivered"
        | "returned"
        | "problem"
        | "cancelled"
      supplier_invoice_status:
        | "draft"
        | "submitted"
        | "approved"
        | "posted"
        | "partially_paid"
        | "paid"
        | "disputed"
        | "cancelled"
        | "reversed"
      supply_method:
        | "supplier_case_and_print"
        | "falcon_case_print_only"
        | "ready_stock"
        | "free_reprint"
        | "paid_reprint"
        | "no_production"
      user_status: "pending" | "active" | "suspended" | "disabled"
      withdrawal_status:
        | "draft"
        | "submitted"
        | "approved"
        | "rejected"
        | "executed"
        | "cancelled"
        | "expired"
        | "reversed"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  api: {
    Enums: {},
  },
  public: {
    Enums: {
      accounting_period_status: [
        "open",
        "closing",
        "closed",
        "reopened_exceptionally",
      ],
      approval_action_type: ["approve", "reject", "cancel"],
      approval_status: [
        "draft",
        "submitted",
        "approved",
        "rejected",
        "expired",
        "cancelled",
        "consumed",
      ],
      bonus_review_status: [
        "draft",
        "calculated",
        "reviewed",
        "approved",
        "rejected",
        "superseded",
      ],
      command_status: ["in_progress", "succeeded", "failed_terminal"],
      courier_settlement_line_type: [
        "contractual_cod_receivable",
        "prepaid_delivery_payable",
        "delivery_fee_payable",
        "return_fee_payable",
        "approved_deduction",
        "adjustment",
        "prior_carry_forward",
        "remittance",
        "claim",
        "dispute",
      ],
      employee_advance_status: [
        "draft",
        "approved",
        "paid",
        "partially_recovered",
        "recovered",
        "cancelled",
        "reversed",
      ],
      employee_kind: [
        "moderator",
        "operations",
        "finance",
        "management",
        "other",
      ],
      employee_status: [
        "draft",
        "active",
        "on_leave",
        "terminated",
        "inactive",
      ],
      expense_status: [
        "draft",
        "submitted",
        "approved",
        "partially_paid",
        "paid",
        "cancelled",
        "reversed",
      ],
      fulfillment_status: [
        "draft",
        "planned",
        "queued",
        "in_production",
        "partially_fulfilled",
        "fulfilled",
        "partially_returned",
        "returned",
        "cancelled",
        "problem",
      ],
      inventory_movement_type: [
        "purchase_receipt",
        "transfer",
        "reservation",
        "reservation_release",
        "production_issue",
        "production_receipt",
        "sale",
        "customer_return",
        "damage",
        "loss",
        "adjustment",
        "gift_consumption",
        "packaging_consumption",
      ],
      item_type: [
        "paid_product",
        "accessory",
        "gift",
        "design_service",
        "replacement",
        "free_reprint",
        "paid_reprint",
        "packaging",
      ],
      journal_status: ["draft", "posted", "reversed"],
      order_status: [
        "new",
        "waiting_customer",
        "waiting_deposit",
        "confirmed",
        "in_print_batch",
        "printing",
        "received_from_printer",
        "quality_check",
        "ready_to_ship",
        "shipped",
        "partially_delivered",
        "delivered",
        "partially_returned",
        "returned",
        "cancelled",
        "problem",
        "financially_settled",
      ],
      partner_loan_status: [
        "draft",
        "active",
        "partially_repaid",
        "repaid",
        "cancelled",
        "reversed",
      ],
      partner_transaction_type: [
        "capital_contribution",
        "capital_return",
        "current_account_credit",
        "current_account_debit",
      ],
      partner_withdrawal_type: [
        "available_profit_draw",
        "future_profit_advance",
        "expense_reimbursement",
        "partner_loan_repayment",
        "other_approved",
      ],
      payment_review_status: [
        "pending_review",
        "confirmed",
        "rejected",
        "reversed",
      ],
      payment_status: [
        "no_payment",
        "partial",
        "required_deposit_paid",
        "fully_prepaid",
        "cash_on_delivery",
        "overpaid",
        "refund_due",
        "partially_refunded",
        "fully_refunded",
      ],
      payroll_status: [
        "draft",
        "calculated",
        "approved",
        "partially_paid",
        "paid",
        "overdue",
        "cancelled",
        "reversed",
      ],
      print_batch_status: [
        "draft",
        "sent",
        "acknowledged",
        "in_production",
        "partially_received",
        "fully_received",
        "quality_check",
        "issue_detected",
        "ready_for_invoice",
        "partially_paid",
        "fully_paid",
        "closed",
        "cancelled",
      ],
      production_attempt_status: [
        "planned",
        "queued",
        "sent",
        "partially_received",
        "received",
        "qc_complete",
        "reprint_planned",
        "closed",
        "cancelled",
      ],
      profit_distribution_status: [
        "draft",
        "submitted",
        "approved",
        "posted",
        "cancelled",
        "reversed",
      ],
      qc_status: ["pending", "accepted", "partially_accepted", "rejected"],
      return_disposition: [
        "pending_inspection",
        "resellable",
        "damaged",
        "reprint",
        "discarded",
        "not_returned",
      ],
      settlement_status: [
        "draft",
        "prepared",
        "reviewed",
        "approved",
        "posted",
        "disputed",
        "cancelled",
      ],
      shipment_kind: ["primary", "split", "replacement", "return_to_customer"],
      shipment_status: [
        "draft",
        "dispatched",
        "partially_delivered",
        "delivered",
        "returned",
        "problem",
        "cancelled",
      ],
      supplier_invoice_status: [
        "draft",
        "submitted",
        "approved",
        "posted",
        "partially_paid",
        "paid",
        "disputed",
        "cancelled",
        "reversed",
      ],
      supply_method: [
        "supplier_case_and_print",
        "falcon_case_print_only",
        "ready_stock",
        "free_reprint",
        "paid_reprint",
        "no_production",
      ],
      user_status: ["pending", "active", "suspended", "disabled"],
      withdrawal_status: [
        "draft",
        "submitted",
        "approved",
        "rejected",
        "executed",
        "cancelled",
        "expired",
        "reversed",
      ],
    },
  },
} as const

