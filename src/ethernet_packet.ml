type t = {
  source : Macaddr.t;
  destination : Macaddr.t;
  ethertype : Mirage_protocols.Ethernet.proto;
}

type error = string

let pp fmt t =
  Format.fprintf fmt "%a -> %a: %a" Macaddr.pp t.source
    Macaddr.pp t.destination Mirage_protocols.Ethernet.pp_proto t.ethertype

let equal {source; destination; ethertype} q =
  (Macaddr.compare source q.source) = 0 &&
  (Macaddr.compare destination q.destination) = 0 &&
  Ethernet_wire.(compare (ethertype_to_int ethertype) (ethertype_to_int q.ethertype)) = 0

module Unmarshal = struct

  let of_cstruct frame =
    let open Ethernet_wire in
    if Cstruct.len frame >= sizeof_ethernet then
      match get_ethernet_ethertype frame |> int_to_ethertype with
      | None -> Error (Printf.sprintf "unknown ethertype 0x%x in frame"
                                (get_ethernet_ethertype frame))
      | Some ethertype ->
        let payload = Cstruct.shift frame sizeof_ethernet
        and source = Macaddr.of_bytes_exn (copy_ethernet_src frame)
        and destination = Macaddr.of_bytes_exn (copy_ethernet_dst frame)
        in
        Ok ({ destination; source; ethertype;}, payload)
    else
      Error "frame too small to contain a valid ethernet header"
end

module Marshal = struct
  open Rresult

  let check_len buf =
    if Ethernet_wire.sizeof_ethernet > Cstruct.len buf then
      Error "Not enough space for an Ethernet header"
    else Ok ()

  let unsafe_fill t buf =
    let open Ethernet_wire in
    set_ethernet_dst (Macaddr.to_bytes t.destination) 0 buf;
    set_ethernet_src (Macaddr.to_bytes t.source) 0 buf;
    set_ethernet_ethertype buf (ethertype_to_int t.ethertype);
    ()

  let into_cstruct t buf =
    check_len buf >>= fun () ->
    Ok (unsafe_fill t buf)

  let make_cstruct t =
    let buf = Cstruct.create Ethernet_wire.sizeof_ethernet in
    Cstruct.memset buf 0x00; (* can be removed in the future *)
    unsafe_fill t buf;
    buf
end
