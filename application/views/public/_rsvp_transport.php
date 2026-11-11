<?php defined('BASEPATH') OR exit('No direct script access allowed');
$shuttle_return = isset($transport_invite['shuttle_return']) ? $transport_invite['shuttle_return'] : '';
?>
<fieldset class="rsvp-transport" data-rsvp-transport>
  <legend><?= e(__('Xe đưa đón từ Hà Nội')) ?></legend>
  <label class="rsvp-transport-toggle">
    <input type="checkbox" name="shuttle" value="1"<?= $shuttle_return !== '' ? ' checked' : '' ?>>
    <span><?= e(__('Tôi đăng ký đi xe từ Hà Nội do gia đình chuẩn bị')) ?></span>
  </label>
  <p class="rsvp-transport-hint"><?= e(__('Xe đón từ Hà Nội về dự cưới vào chiều thứ Bảy. Có xe về Hà Nội ngay tối thứ Bảy hoặc sau lễ cưới Chủ nhật.')) ?></p>
  <label data-shuttle-return><?= e(__('Thời điểm về Hà Nội')) ?>
    <select name="shuttle_return">
      <option value=""><?= e(__('Chọn thời điểm về')) ?></option>
      <option value="same_evening"<?= $shuttle_return === 'same_evening' ? ' selected' : '' ?>><?= e(__('Tối thứ Bảy')) ?></option>
      <option value="next_day"<?= $shuttle_return === 'next_day' ? ' selected' : '' ?>><?= e(__('Sau lễ cưới Chủ nhật')) ?></option>
    </select>
  </label>
  <p class="err" data-shuttle-error role="alert" hidden><?= e(__('Vui lòng chọn thời điểm về Hà Nội khi đăng ký xe.')) ?></p>
</fieldset>
