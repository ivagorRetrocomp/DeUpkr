; Upkr decompressor Intel 8088/8086 version by Ivan Gorodetsky. Compile with FASM
; based on z80 version by Peter "Ped" Helcmanovsky (C) 2022, licensed same as upkr project ("unlicensed") 
;
; v1 (2022-11-01) - 188 bytes
; Memory model - Tiny
;
; Input:
; SI=source
; DI=destination
; call shrinkler_decrunch

BACKWARD equ 0

macro SetDir {
 if BACKWARD eq 1
  std
 else
  cld
 end if
}

macro NextSI {
 if BACKWARD eq 1
  dec si
 else
  inc si
 end if
}

macro NextDI {
 if BACKWARD eq 1
  dec di
 else
  inc di
 end if
}

macro AddOffset {
 if BACKWARD eq 1
  add si,bp
 else
  sub si,bp
 end if
}

NUMBER_BITS	equ (16+15)
; you may change probs to point to any 256-byte aligned free buffer (size 320 bytes)
probs		  equ 0FA00h
probs_real_c	  equ 1 + 255 + 1 + (2*NUMBER_BITS)
probs_c 	  equ (probs_real_c + 1) and 0FFFEh
probs_e 	  equ probs + probs_c


deupkr:
		SetDir
		mov ah,80h
		mov dx,(probs_c / 2)
		mov bx,(probs_e)
reset_probs:
		dec bx
		mov [bx],ah
		dec bx
		mov [bx],ah
		dec dl
		jnz reset_probs
decompress_data:
		mov bl,0
		call decode_bit
		jc copy_chunk
		inc bl
decode_byte:
		call decode_bit
		rcl bl,1
		jnc decode_byte
		mov [di],bl
		NextDI
		mov ch,bh
		jmp decompress_data
copy_chunk:
		mov al,bh
		inc bh
		cmp al,ch
		jc SkipCall1
		call decode_bit
SkipCall1:
		jnc keep_offset
		call decode_number
		loop NotExit
		ret
NotExit:
		mov bp,cx
keep_offset:
		mov bl,(257 + NUMBER_BITS - 1) and 255
		call decode_number
		push si
		mov si,di
		AddOffset
		rep movsb
		pop si
		mov ch,bh
		dec bh
		jnz decompress_data

inc_c_decode_bit:
		inc bl
decode_bit:
		push cx
		test dx,8000h
		jnz state_b15_set
state_b15_zero:
		add ah,ah
		jnz has_bit
		mov ah,[si]
		NextSI
		adc ah,ah
has_bit:
		rcl dx,1
		test dx,8000h
		jz state_b15_zero
state_b15_set:
		mov al,[bx]
		dec al
		cmp al,dl
		inc al
		push bx
		mov bl,dl
		push ax
		pushf
		jnc bit_is_0
		neg al
bit_is_0:
		mov ch,0
		mov bh,ch

		mov cl,al

		mul dh
		add ax,bx
		popf
		jnc bit_is_0_2
		dec ch
		add ax,cx
bit_is_0_2:
		mov dx,ax
		pop ax
		rcr al,1
		mov cl,3
		shr al,cl
		adc al,-16
		mov cl,al
		pop bx
		mov al,[bx]
		sub al,cl
		mov [bx],al
		add al,ch
		pop cx
		ret

decode_number:
		mov cx,0FFFFh
		clc
		jmp SkipCall2
decode_number_loop:
		call inc_c_decode_bit
SkipCall2:
		rcr cx,1
		call inc_c_decode_bit
		jc decode_number_loop
fix_bit_pos:
		cmc
		rcr cx,1
		jc fix_bit_pos
		ret
