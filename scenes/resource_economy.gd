extends RefCounted
class_name ResourceEconomy


static func sorted_keys_by_value_desc(values: Dictionary) -> Array:
	var keys: Array = values.keys()
	keys.sort_custom(func(x: String, y: String) -> bool:
		return float(values.get(x, 0.0)) > float(values.get(y, 0.0))
	)
	return keys


static func analyze_balances(assets: Dictionary, needs: Dictionary, neutral_need_value: float = 0.0, empty_value: float = -999.0) -> Dictionary:
	var current_excess := {}
	var current_needs := {}
	var excess_res = null
	var needed_res = null
	var high_amt_excess := 0.0
	var high_amt_needed := 0.0
	for res in assets.keys():
		current_excess[res] = empty_value
		current_needs[res] = empty_value
		var current_amount = float(assets.get(res, 0.0))
		var needed_amount = float(needs.get(res, 0.0))
		var delta = current_amount - needed_amount
		if current_amount > needed_amount:
			high_amt_excess = delta
			excess_res = res
			current_excess[res] = high_amt_excess
		if current_amount < needed_amount:
			high_amt_needed = -1.0 * delta
			needed_res = res
			current_needs[res] = high_amt_needed
		else:
			current_needs[res] = neutral_need_value
	return {
		"current_excess": current_excess,
		"current_needs": current_needs,
		"excess_res": excess_res,
		"needed_res": needed_res,
		"high_amt_excess": high_amt_excess,
		"high_amt_needed": high_amt_needed,
		"excess_keys": sorted_keys_by_value_desc(current_excess),
		"needed_keys": sorted_keys_by_value_desc(current_needs)
	}


static func build_trade_dict(from_agent: Node, to_agent: Node, trade_asset: String, trade_amount: int, trade_type: String = "send", return_res: Variant = null, return_amt: Variant = null, extra_fields: Dictionary = {}) -> Dictionary:
	var trade_dict := {
		"from_agent": from_agent,
		"to_agent": to_agent,
		"trade_path": [from_agent, to_agent],
		"trade_asset": trade_asset,
		"trade_amount": trade_amount,
		"trade_type": trade_type,
		"return_res": return_res,
		"return_amt": return_amt
	}
	for key in extra_fields.keys():
		trade_dict[key] = extra_fields[key]
	return trade_dict
