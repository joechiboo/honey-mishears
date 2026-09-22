# Rive 角色素材放這裡

把做好的檔案命名為 `wife.riv` 放進本資料夾即可，程式會自動偵測並改用 Rive 角色。
Rive 是最優先的渲染器，放進去就會蓋過圖片角色，不必先把
[`assets/character/default/`](../character/default/README.md) 的圖刪掉。

檔案不存在時往下退：有圖片素材就用圖片角色，都沒有才用內建的佔位角色。

狀態機規格請見 [`docs/rive_state_machine.md`](../../docs/rive_state_machine.md)。
