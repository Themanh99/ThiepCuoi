<?php
// Run: php tests/rsvp_transport.php (requires sqlite3, mbstring and openssl).
define('BASEPATH', __DIR__ . '/../system/');
function __($text) { return $text; }
function setting($key) { return '0'; }
function now_str() { return '2026-11-12 12:00:00'; }
function check($condition, $message) {
    if (!$condition) throw new RuntimeException($message);
}
class CI_Model { public $db; public $load; }
class TestLoader { public function model($name) {} }
class TestDatabase {
    public $conn;
    public function __construct() { $this->conn = new SQLite3(':memory:'); }
    public function update($table, $data, $where) {
        $set = implode(', ', array_map(function ($key) { return "$key = :$key"; }, array_keys($data)));
        $stmt = $this->conn->prepare("UPDATE $table SET $set WHERE id = :_id");
        foreach ($data as $key => $value) $stmt->bindValue(":$key", $value, $value === null ? SQLITE3_NULL : SQLITE3_TEXT);
        $stmt->bindValue(':_id', $where['id'], SQLITE3_INTEGER);
        return $stmt->execute();
    }
    public function get_where($table, $where) {
        $stmt = $this->conn->prepare("SELECT * FROM $table WHERE id = :id");
        $stmt->bindValue(':id', $where['id'], SQLITE3_INTEGER);
        $row = $stmt->execute()->fetchArray(SQLITE3_ASSOC);
        return new class($row) {
            private $row;
            public function __construct($row) { $this->row = $row; }
            public function row_array() { return $this->row; }
        };
    }
}
require __DIR__ . '/../application/models/Invite_model.php';
$db = new TestDatabase();
foreach (glob(__DIR__ . '/../application/sql/*.sql') as $sql) {
    if (basename($sql) !== '006_rsvp_transport.sql') $db->conn->exec(file_get_contents($sql));
}
$db->conn->exec("INSERT INTO invites (id, code, name, salutation, created_at) VALUES (1, 'abcdefgh', 'Khách thử', '', '2026-11-12')");
$migration = __DIR__ . '/../application/sql/006_rsvp_transport.sql';
if (is_file($migration)) $db->conn->exec(file_get_contents($migration));
$model = new Invite_model();
$model->db = $db;
$model->load = new TestLoader();
$guest = $model->find(1);
check(isset($guest['shuttle_return']) && $guest['shuttle_return'] === '', 'Existing guests must default to no shuttle booking');
foreach (array('same_evening', 'next_day') as $return) {
    $guest = $model->respond($guest, 'yes', 2, '', '', $return);
    check($guest['shuttle_return'] === $return, 'Must save the selected return journey');
    check((int) $guest['guests'] === 2, 'Attendance count must remain unchanged');
}
$guest = $model->respond($guest, 'yes', 3, '');
check($guest['shuttle_return'] === 'next_day', 'Admin attendance updates must preserve the booking');
$guest = $model->respond($guest, 'no', 3, '');
check($guest['shuttle_return'] === '' && (int) $guest['guests'] === 0, 'Declining must clear the booking');
$guest = $model->respond($guest, 'yes', 1, '', '', 'same_evening');
$guest = $model->respond($guest, 'yes', 1, '', '', '');
check($guest['shuttle_return'] === '', 'Unchecking the shuttle must cancel the booking');
$guest = $model->respond($guest, 'yes', 1, '', '', 'invalid');
check($guest['shuttle_return'] === '', 'Unknown return values must not be stored');
echo "PASS: migration defaults, both journeys, admin preservation, declining, cancellation and invalid values\n";
