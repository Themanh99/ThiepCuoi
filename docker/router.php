<?php
// Router của php -S trong Docker: chạy prepend.php rồi giao cho router.php gốc.
require __DIR__ . '/prepend.php';
return require __DIR__ . '/../router.php';
