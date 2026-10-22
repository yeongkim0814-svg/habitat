extends RefCounted
## 상점(D36, D79): 재화 구매·판매와 교환. 상태(돈, 소지품, 교환 사용량)는 Game에 있다.
## 교환 일일 수량은 호감도 단계로 정한다: daily[호감도], 마지막 값을 넘으면 마지막 값. 0이면 아직 안 보인다.

static func daily(g, shop: String, offer: Dictionary) -> int:
	var tiers: Array = offer["daily"]
	return int(tiers[mini(int(g.favor.get(shop, 0)), tiers.size() - 1)])

static func left(g, shop: String, offer: Dictionary) -> int:
	return daily(g, shop, offer) - int(g.barter_used.get(offer["id"], 0))

## 상점 화면에 보일 교환 목록(호감도로 열린 것만).
static func offers(g, shop: String) -> Array:
	var rows := []
	for offer in g.data["shops"][shop]["barter"]:
		if daily(g, shop, offer) > 0:
			rows.append({"id": offer["id"], "give": offer["give"], "get": offer["get"], "left": left(g, shop, offer)})
	return rows

static func buy(g, shop: String, item: String) -> bool:
	var price = g.data["shops"][shop]["sell"].get(item)
	if price == null or g.money < int(price):
		return false
	g.money -= int(price)
	g.add(item, 1)
	return true

static func sell(g, shop: String, item: String) -> bool:
	var price = g.data["shops"][shop]["buy"].get(item)
	if price == null or g.count(item) < 1:
		return false
	g.add(item, -1)
	g.money += int(price)
	return true

static func barter(g, shop: String, id: String) -> bool:
	for offer in g.data["shops"][shop]["barter"]:
		if offer["id"] != id:
			continue
		if left(g, shop, offer) < 1:
			return false
		for item in offer["give"]:
			if g.count(item) < int(offer["give"][item]):
				return false
		for item in offer["give"]:
			g.add(item, -int(offer["give"][item]))
		g.add(offer["get"], 1)
		g.barter_used[id] = int(g.barter_used.get(id, 0)) + 1
		return true
	return false
